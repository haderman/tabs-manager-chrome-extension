function init() {
  listenPopupMsgs();
  listenNewtabMsgs();
  listenTabEvents();
  listenStorageEvents();

  getWorkspacesList(arr => {
    arr.forEach(name => {
      getWorkspace(name, (workspace) => {
        console.log(`${name} ->`);
        console.dir(workspace[name]);
      });
    });
  });
}

function listenStorageEvents() {
  chrome.storage.onChanged.addListener(function(changes, namespace) {
    console.log('storage changed');
    console.dir(changes);
    for (var key in changes) {
      var storageChange = changes[key];
      console.log('Storage key "%s" in namespace "%s" changed. ' +
                  'Old value was "%s", new value is "%s".',
                  key,
                  namespace,
                  storageChange.oldValue,
                  storageChange.newValue);
    }
  });
}

function getTabs(callback = () => {}) {
  chrome.tabs.query({ currentWindow: true }, callback);
}

function listenTabEvents() {
  chrome.tabs.onCreated.addListener(() => {
    console.log('Created!');
  });

  chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
    const { status } = changeInfo;
    if (status !== 'complete') return;
  });
}

function listenPopupMsgs() {
  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'get_titles':
        // sendResponse('response');
        break;
      case 'create_workspace':
        createWorkspace(request.payload);
        break;
      default:
        break;
    }
  });
}

function listenNewtabMsgs() {
  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'get_workspaces':
        console.log('get workspaces');
        getWorkspacesList(listWorkspaces => {
          chrome.extension.sendMessage({
            type: 'got_workspaces',
            payload: listWorkspaces,
          });
        });
        break;
      default:
        break;
    }
  })
}

function createWorkspace(name) {
  const mapTitleAndUrl = map(({ title, url }) => ({ title, url }));
  const create = tabs => ({ name, tabs, type: 'workspace'});
  const save = compose(setWorkspace, create, mapTitleAndUrl);
  getTabs(save);
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

chrome.runtime.onInstalled.addListener(init);


// HELPERS

// origin for this funciton: https://gist.github.com/JamieMason/172460a36a0eaef24233e6edb2706f83
function compose(...fns) {
  return fns.reduceRight((prevFn, nextFn) =>
    (...args) => nextFn(prevFn(...args)),
    value => value
  );
};

function logger(label) {
  return value => {
    console.log(label + ' out: ');
    if (typeof value === "string") console.log(value);
    else console.dir(value);
    return value;
  }
}

function map(fn) {
  return arr => arr.map(fn);
}

function merge(objToMerge) {
  return baseObject => ({ ...baseObject, ...objToMerge });
}
