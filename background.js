const chromePromise = new ChromePromise();

// Msgs
const NONE = 'NONE';
const STORAGE_UPDATED = 'STORAGE_UPDATED';
const TAB_UPDATED = 'TAB_UPDATED';
const TAB_REMOVED = 'TAB_REMOVED';
const EXTERNAL_MESSAGE = 'EXTERNAL_MESSAGE';
const WORKSPACE_OPENED = 'WORKSPACE_OPENED';
const NEW_WINDOW_CREATED = 'NEW_WINDOW_CREATED';
const SAVE_WORKSPACE = 'SAVE_WORKSPACE';
const WORKSPACE_SAVED = 'WORKSPACE_SAVED';

// return [model, msg]
async function init() {
  const workspaces = await chromePromise.storage.sync.get('workspaces_list');
  const model = {
    workspaces: workspaces.workspaces_list || [],
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

      if (!workspaceName) return;

      const newWorkspaces = model.workspaces.includes(workspaceName)
        ? model.workspaces
        : [...model.workspaces, workspaceName];

      chromePromise.tabs.query({ windowId })
        .then(logger('tabs'))
        .then(map(pick(['title', 'url', 'favIconUrl'])))
        .then(tabs => ({
          [workspaceName]: tabs,
          workspaces_list: newWorkspaces
        }))
        .then(chromePromise.storage.sync.set)
        .then(() => {
          pipe(
            set(`windows.${window.id}.workspace`, workspaceName),
            set('workspaces', newWorkspaces),
            setModel
          )(model)
        })
        .catch(err => {
          console.warn('Error updading tabs in storage: ', err);
        });
    },
    // Messages from popup or newtab
    EXTERNAL_MESSAGE: async (request, sender, sendResponse) => {
      const workspaceName = request.payload;
      const window = request.window;

      switch (request.type) {
        case 'get_model':
          setModel({ ...model });
          break;
        case 'request_to_create_a_workspace':
          chromePromise.tabs.query({ currentWindow: true })
            .then(map(pick(['title', 'url'])))
            .then(tabs => ({
              [workspaceName]: tabs,
              workspaces_list: model.workspaces.includes(workspaceName)
                ? model.workspaces
                : [...model.workspaces, workspaceName],
            }))
            .then(chromePromise.storage.sync.set)
            .then(() => {
              const newModel = set(`windows.${window.id}.workspace`, workspaceName)(model);
              setModel(newModel);
            })
            .catch(err => {
              console.warn('Error creating a workspace: ', err);
            });
          break;
        case 'request_to_open_workspace':
          const currentWorkspaceName = model.windows[window.id]
            ? model.windows[window.id].workspace
            : 'last-sesion';
          
          const tabsToClose = await chromePromise.tabs.query({ windowId: window.id });
        
          const tabsToOpen = await 
            chromePromise.storage.sync.get(workspaceName)
            .then(prop(workspaceName))
            .then(map(prop('url')))
            .then(map(url => ({ windowId: window.id, url })))
            .catch(err => {
              console.warn('Error getting workspace data from storage: ', err);
            });
          
          tabsToOpen.forEach(tab => chromePromise.tabs.create(tab));
          chromePromise.tabs.remove(tabsToClose.map(prop('id')));

          const dataToSave = {
            [currentWorkspaceName]: tabsToClose.map(pick(['title', 'url'])),
            workspaces_list: [currentWorkspaceName, ...model.workspaces].filter(onlyUnique),
          };
          chromePromise.storage.sync.set(dataToSave)
            .catch(err => {
              console.warn('Error saving workspace data to storage: ', err);
            });

          setModel(
            pipe(
              set(`windows.${window.id}.workspace`, workspaceName),
              set('workspaces', dataToSave.workspaces_list)
            )(model)
          );
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
function baseCompose(f, g) {
  return (...args) => f(g(...args));
}

function compose(...fns) {
  return fns.reduce(baseCompose);
}

function pipe(...fns) {
  return fns.reduceRight(baseCompose);
}

function logger(label) {
  return value => {
    console.log(label);
    const print = typeof value === 'string' ? console.log : console.dir;
    print(value);
    return value;
  }
}

function map(fn) {
  return arr => arr.map(fn);
}

function forEach(fn) {
  return arr => arr.forEach(fn);
}

function merge(objToMerge) {
  return baseObject => ({ ...baseObject, ...objToMerge });
}

function onlyUnique(value, index, arr) { 
  return arr.indexOf(value) === index;
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

function set(path = '', value) {
  return (obj = {}) => {
    const clone = { ...obj };
    const props = path.split('.');
    switch (props.length) {
      case 1:
        clone[props[0]] = value;
        break;
      case 2:
        var [first, second] = props;
        if (first in clone) {
          if (second in clone[first]) {
            clone[first][second] = value;
          } else {
            clone[first] = { [second]: value };
          }
        }
        break;
      case 3:
        var [first, second, third] = props;
        if (first in clone) {
          if (second in clone[first]) {
            clone[first][second][third] = value;
          } else {
            clone[first][second] = { [third]: value };
          }
        }
      default:
        break;
    }
    return clone;
  }
}


