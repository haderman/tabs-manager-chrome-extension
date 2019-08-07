// Msgs
const STORAGE_UPDATED = 'STORAGE_UPDATED';
const TAB_CREATED = 'TAB_CREATED';
const TAB_UPDATED = 'TAB_UPDATED';
const EXTERNAL_MESSAGE = 'EXTERNAL_MESSAGE';
const NONE = 'NONE';

// return [model, msg]
async function init() {
  const model = {
    workspaces: await new Promise((resolve, reject) => {
      chrome.storage.sync.get('workspaces_list', workspaces => {
        resolve(workspaces.workspaces_list);
      });
    }),
  };
  return model;
};

function update(msg, model) {
  const handlers = {
    STORAGE_UPDATED: (changes, namespace) => {
      console.log(STORAGE_UPDATED);
      console.dir(changes);
      return [model, NONE];
    },
    TAB_CREATED: (args) => {
      console.log(TAB_CREATED, args);
      return [{...model }, NONE];
    },
    TAB_UPDATED: (tabId, changeInfo) => {
      console.log(TAB_UPDATED);
      // const { status } = changeInfo;
      if (status !== 'complete') return [model, NONE];

      console.log(tabId)
      return [model, NONE];
    },
    // Messages from popup or newtab
    EXTERNAL_MESSAGE: (request, sender, sendResponse) => {
      switch (request.type) {
        case 'get_model':
          return [{ ...model }, NONE];
        case 'get_titles':
          // sendResponse('response');
          return [model, NONE];
        case 'create_workspace':
          chrome.tabs.query({ currentWindow: true }, tabs => {
            const name = request.payload; 
            const mapTitleAndUrl = map(({ title, url }) => ({ title, url }));
            const create = tabs => ({ name, tabs, type: 'workspace' });
            const save = compose(setWorkspace, create, mapTitleAndUrl);
            save(tabs);
          })
          return [model, NONE];
        case 'get_workspaces':
          console.log('get workspaces');
          getWorkspacesList(listWorkspaces => {
            chrome.extension.sendMessage({
              type: 'got_workspaces',
              payload: listWorkspaces,
            });
          });
          return [model, NONE];
        case 'open_workspace':
          openWorkspace(request.payload);
          return [model, NONE];
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

  // events from other scripts
  chrome.extension.onMessage.addListener(callback(EXTERNAL_MESSAGE));
}

async function getWorkspaces() {
  return new Promise((resolve, reject) => {
    chrome.storage.sync.get('workspaces_list', workspaces => {
      resolve(workspaces.workspaces_list);
    })
  });
}

function openWorkspace(workspace) {
  getWorkspace(workspace, list => {
    const urls = map(tab => tab.url)(list[workspace].tabs);
    console.log(urls);
    chrome.windows.create({ url: urls });
  });
}

function getWorkspace(name, func) {
  chrome.storage.sync.get(name, func);
}

function getWorkspacesList(func) {
  chrome.storage.sync.get('workspaces_list', ({ workspaces_list }) => {
    console.log('list: ', workspaces_list);
    if (func) {
      func(Array.isArray(workspaces_list) ? workspaces_list : []);
    }
  });
}

function setWorkspace({ name, ...rest }) {
  getWorkspacesList(arr => {
    chrome.storage.sync.set({
      [name]: rest,
      workspaces_list: [...arr, name]
    });
  });
}

chrome.runtime.onInstalled.addListener(() => {
  main(init, update, subscriptions);
});


// HELPERS

async function main(init, update, subscriptions) {
  let model = await init();
  
  const updateModel = (msg) => (...args) => {
    const [newModel, newMsg] = update(msg, model)(...args);
    
    if (model !== newModel) {
      logModelUpdated(msg, newModel);
      chrome.extension.sendMessage({ type: 'MODEL_UPDATED', payload: newModel });
      model = newModel;
    }
    
    if (newMsg !== NONE) {
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