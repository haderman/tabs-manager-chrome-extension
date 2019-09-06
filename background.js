// Msgs
const NONE = 'NONE';
const STORAGE_UPDATED = 'STORAGE_UPDATED';
const TAB_UPDATED = 'TAB_UPDATED';
const TAB_REMOVED = 'TAB_REMOVED';
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

function update(msg, model, setModel) {
  const handlers = {
    NEW_WINDOW_CREATED: (window) => {
      setModel({
        ...model,
        windows: {
          ...model.windows,
          [window.id]: {
            workspace: undefined
          }
        }
      });
    },
    STORAGE_UPDATED: (changes, namespace) => {
      for (var key in changes) {
        var storageChange = changes[key];
        console.log('Storage key "%s" in namespace "%s" changed. ' +
                    'Old value was "%s", new value is "%s".',
                    key,
                    namespace,
                    storageChange.oldValue,
                    storageChange.newValue);
      }
      return [model, NONE];
    },
    TAB_UPDATED: (tabId, changeInfo, tabInfo) => {
      const { status } = changeInfo;
      if (status !== 'complete') return;

      const { windows } = model;
      const { windowId } = tabInfo;
      const workspaceName = windowId in windows && windows[windowId].workspace;
      
      if (workspaceName) {
        chrome.tabs.query({ windowId }, tabs => {
          const pickTitleAndUrl = map(pick(['title', 'url']));
          
          const newWorkspaces = model.workspaces.includes(workspaceName)
            ? model.workspaces
            : [...model.workspaces, workspaceName];

          const objToSave = {
            [workspaceName]: pickTitleAndUrl(tabs),
            workspaces_list: newWorkspaces
          };
          
          chrome.storage.sync.set(objToSave, () => {
            setModel({
              ...model,
              workspaces: newWorkspaces,
              windows: {
                ...model.windows,
                [windowId]: {
                  workspace: workspaceName
                }
              }
            })
          });
        });
      }
    },
    OPEN_WORKSPACE: ([name, content]) => {
      const url = content.map(prop('url'));
      chrome.windows.create({ url }, newWindow => {
        setModel({
          ...model,
          windows: {
            ...model.windows,
            [window.id]: {
              workspace: name
            }
          }
        });
      });
    },
    // Messages from popup or newtab
    EXTERNAL_MESSAGE: (request, sender, sendResponse) => {
      const workspaceName = request.payload;
      const window = request.window;

      switch (request.type) {
        case 'get_model':
          setModel({ ...model });
          break;
        case 'request_to_create_a_workspace':
          chrome.tabs.query({ currentWindow: true }, tabs => {
            const pickTitleAndUrl = map(pick(['title', 'url']));
            const newWorkspaces = (
              model.workspaces.includes(workspaceName)
              ? model.workspaces
              : [...model.workspaces, workspaceName]
            );
            const objToSave = {
              [workspaceName]: pickTitleAndUrl(tabs),
              workspaces_list: newWorkspaces,
            };
            chrome.storage.sync.set(objToSave, () => {
              setModel({
                ...model,
                workspaces: newWorkspaces,
                windows: {
                  ...model.windows,
                  [window.id]: {
                    workspace: workspaceName
                  }
                }
              })
            });
          });
          break;
        case 'request_to_open_workspace':
          chrome.storage.sync.get(workspaceName, workspaceContent => {
            chrome.tabs.query({ windowId: window.id }, tabs => {
              workspaceContent[workspaceName].map(prop('url')).forEach(url => {
                chrome.tabs.create({ windowId: window.id, url })
              })
              setModel({
                ...model,
                windows: {
                  ...model.windows,
                  [window.id]: {
                    workspace: workspaceName
                  }
                }
              });
              chrome.tabs.remove(map(prop('id'))(tabs), () => {
                const content = workspaceContent[workspaceName];
              });
            })

            // chrome.windows.create({ url }, newWindow => {
            //   setModel({
            //     ...model,
            //     windows: {
            //       ...model.windows,
            //       [newWindow.id]: {
            //         workspace: workspaceName
            //       }
            //     }
            //   });
            // });
          })
          break;
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
  chrome.tabs.onUpdated.addListener(callback(TAB_UPDATED));
  chrome.tabs.onRemoved.addListener(callback(TAB_REMOVED));

  // events from other scripts (popup | newtab)
  chrome.extension.onMessage.addListener(callback(EXTERNAL_MESSAGE));

  // windows events
  chrome.windows.onCreated.addListener(callback(NEW_WINDOW_CREATED));
}

main(init, update, subscriptions);



// HELPERS

async function main(init, update, subscriptions) {
  let model = await init();
  
  const setModel = msg => newModel => {
    if (model !== newModel) {
      model = newModel
      chrome.extension.sendMessage({ type: 'MODEL_UPDATED', payload: model });
      logModelUpdated(msg, newModel)
    }
  }

  const callUpdate = msg => (...args) => {
    update(msg, model, setModel(msg))(...args);
  }

  const updateModel = (msg) => async (...args) => {
    const [newModel, newMsg] = update(msg, model, setModel)(...args);
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

  subscriptions(callUpdate);
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
  return obj => obj[nameProp];
}