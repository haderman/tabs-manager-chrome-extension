// Msgs
const NONE = 'NONE';
const STORAGE_UPDATED = 'STORAGE_UPDATED';
const TAB_CREATED = 'TAB_CREATED';
const TAB_UPDATED = 'TAB_UPDATED';
const EXTERNAL_MESSAGE = 'EXTERNAL_MESSAGE';
const OPEN_WORKSPACE = 'OPEN_WORKSPACE';
const WORKSPACE_OPENED = 'WORKSPACE_OPENED';
const NEW_WINDOW_CREATED = 'NEW_WINDOW_CREATED';
const SAVE_WORKSPACE = 'SAVE_WORKSPACE';
const WORKSPACE_SAVED = 'WORKSPACE_SAVED';

// return [model, msg]
async function init() {
  const model = {
    workspaces: await new Promise((resolve, reject) => {
      chrome.storage.sync.get('workspaces_list', workspaces => {
        resolve(workspaces.workspaces_list);
      });
    }),
    windows: {},
  };
  return model;
};

function update(msg, model) {
  const handlers = {
    NEW_WINDOW_CREATED: (window) => {
      return [
        {
          ...model,
          windows: {
            ...model.windows,
            [window.id]: {
              workspace: undefined
            }
          }
        },
        NONE
      ]
    },
    STORAGE_UPDATED: (changes, namespace) => {
      console.dir(changes);
      return [model, NONE];
    },
    TAB_CREATED: (args) => {
      console.log(args);
      return [{ ...model }, NONE];
    },
    TAB_UPDATED: (tabId, changeInfo, tabInfo) => {
      const { status } = changeInfo;
      if (status !== 'complete') return [model, NONE];

      console.log(tabInfo.title);
      console.log(tabInfo.url);
      console.log(tabInfo.windowId);
      return [model, NONE];
    },
    OPEN_WORKSPACE: ([name, content]) => {
      console.log('OPEN_WORKSPACE: ', content);
      const url = content.map(prop('url'));
      return [
        { ...model },
        [
          new Promise((resolve, reject) => {
            chrome.windows.create({ url }, newWindow => {
              resolve([name, newWindow]);
            });
          }),
          WORKSPACE_OPENED
        ]
      ]
    },
    WORKSPACE_OPENED: ([name, window]) => {
      return [
        {
          ...model,
          windows: {
            ...model.windows,
            [window.id]: {
              workspace: name
            }
          }
        },
        NONE
      ]
    },
    SAVE_WORKSPACE: ([name, tabs, window]) => {
      const pickTitleAndUrl = map(pick(['title', 'url']));
      const newWorkspaces = [...model.workspaces, name];
      const objToSave = {
        [name]: pickTitleAndUrl(tabs),
        workspaces_list: newWorkspaces,
      };
      
      return [
        { ...model },
        [
          new Promise((resolve, reject) => {
            chrome.storage.sync.set(objToSave, () => {
              resolve([name, newWorkspaces, window]);
            });
          }),
          WORKSPACE_SAVED
        ]
      ];
    },
    WORKSPACE_SAVED: ([name, newWorkspaces, window]) => {
      return [
        {
          ...model,
          workspaces: newWorkspaces,
          windows: {
            ...model.windows,
            [window.id]: {
              workspace: name
            }
          }
        },
        NONE
      ]
    },
    // Messages from popup or newtab
    EXTERNAL_MESSAGE: (request, sender, sendResponse) => {
      switch (request.type) {
        case 'get_model':
          return [{ ...model }, NONE];
        case 'request_to_create_a_workspace':
          return [
            { ...model },
            [
              new Promise((resolve, reject) => {
                chrome.tabs.query({ currentWindow: true }, tabs => {
                  resolve([request.payload, tabs, request.window]);
                });
              }),
              SAVE_WORKSPACE
            ]
          ];
        case 'request_to_open_workspace':
          const workspaceName = request.payload;
          return [
            { ...model, currentWorkspace: workspaceName },
            [
              new Promise((resolve, reject) => {
                chrome.storage.sync.get(workspaceName, workspaceContent => {
                  resolve([workspaceName, workspaceContent[workspaceName]]);
                })
              }),
              OPEN_WORKSPACE
            ]
          ];
        default:
          return [model, NONE];
      }
    }
  };

  return handlers[msg] ? handlers[msg] : () => model;
};

function subscriptions(callback) {
  // storage events subscriptions
  chrome.storage.onChanged.addListener(callback(STORAGE_UPDATED));
  
  // tabs events subscriptions
  chrome.tabs.onCreated.addListener(callback(TAB_CREATED));
  chrome.tabs.onUpdated.addListener(callback(TAB_UPDATED));

  // events from other scripts (popup | newtab)
  chrome.extension.onMessage.addListener(callback(EXTERNAL_MESSAGE));

  // windows events
  chrome.windows.onCreated.addListener(callback(NEW_WINDOW_CREATED));
}

chrome.runtime.onInstalled.addListener(() => {
  main(init, update, subscriptions);
});


// HELPERS

async function main(init, update, subscriptions) {
  let model = await init();
  
  const updateModel = (msg) => async (...args) => {
    const [newModel, newMsg] = update(msg, model)(...args);
    
    if (model !== newModel) {
      logModelUpdated(msg, newModel);
      chrome.extension.sendMessage({ type: 'MODEL_UPDATED', payload: newModel });
      model = newModel;
    }
    
    if (Array.isArray(newMsg)) {
      const value = await newMsg[0];
      updateModel(newMsg[1])(value);
    } else if (newMsg !== NONE) {
      updateModel(newMsg)();
    }
  }
  
  subscriptions(updateModel);
}

function logModelUpdated(msg, newModel) {
  console.group('model updated');
  console.info('msg: ', msg);
  console.info('new model: ', newModel);
  console.groupEnd();
}

// origin for this funciton: https://gist.github.com/JamieMason/172460a36a0eaef24233e6edb2706f83
function compose(...fns) {
  return fns.reduceRight((prevFn, nextFn) =>
    (...args) => nextFn(prevFn(...args)),
    value => value
  );
};

function logger(label) {
  return value => {
    const print = typeof value === 'string' ? console.log : console.dir;
    print(value);
    return value;
  }
}

function map(fn) {
  return arr => arr.map(fn);
}

function merge(objToMerge) {
  return baseObject => ({ ...baseObject, ...objToMerge });
}

function pick(keys) {
  return obj => {
    let out = {};
    
    if (Array.isArray(keys)) {
      keys.forEach(key => {
        if (key in obj) {
          out[key] = obj[key];
        }
      });  
    }

    if (typeof keys === 'string' && keys in obj) {
      out[keys] = obj[keys];
    }
  
    return out;
  } 
}

function prop(nameProp) {
  return obj => {
    return obj[nameProp];
  };
}