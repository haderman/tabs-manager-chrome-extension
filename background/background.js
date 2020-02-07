'use strict';

const chromePromise = new ChromePromise();
const logger = createLogger();

let model = {
  idsOfWindowsOpened: [],
  machinesByWindowsID: {},
  data: {}
};

const appStates = {
  initial: 'loadingApp',
  loadingApp: {
    on: {
      DATA_LOADED: 'checkingForOpenedWindows',
    },
  },
  checkingForOpenedWindows: {
    on: {
      CHECK_COMPLETED: 'subscribingEvents'
    }
  },
  subscribingEvents: {
    on: {
      SUBSCRIBED_TO_EVENTS: 'appLoaded',
    }
  },
  appLoaded: {
    on: {}
  },
};

function createWindowStates() {
  const ifNoData = model.data.__workspaces_ids__.length === 0;

  return {
    initial: ifNoData ? 'noData' : 'idle',
    idle: {
      on: {
        OPEN_WORKSPACE: 'openingWorkspace',
        CREATE_WORKSPACE: 'workspaceInUse',
        UPDATE_WORKSPACE: 'idle',
        DELETE_WORKSPACE: 'idle',
      }
    },
    noData: {
      on: {
        CREATE_WORKSPACE: 'workspaceInUse',
      }
    },
    openingWorkspace: {
      on: {
        WORKSPACE_OPENED: 'workspaceInUse'
      }
    },
    workspaceInUse: {
      on: {
        OPEN_WORKSPACE: 'openingWorkspace',
        UPDATE_WORKSPACE: 'workspaceInUse',
        DELETE_WORKSPACE: 'workspaceInUse',
        DISCONNECT_WORKSPACE: 'idle'
      }
    }
  }
};

function createMachine(states) {
  let currentState = states.initial;

  const _setState = state => { currentState = state; };
  const _isEventAvailable = event => event in states[currentState].on;

  return {
    send(event) {
      if (_isEventAvailable(event)) {
        const newState = states[currentState].on[event];
        logMachineEvent(event, currentState, newState);
        _setState(newState);
      }
      return currentState;
    },
    isEventAvailable(event) {
      return _isEventAvailable(event);
    },
    getCurrentState() {
      return currentState;
    }
  };
}

const appMachine = createMachine(appStates);

function setModel(newModelV2) {
  if (model !== newModelV2) {
    model = newModelV2;
    if (appMachine.getCurrentState() === 'appLoaded') {
      broadcast(model);
    }
  }
}

init();

async function init() {
  setModel({
    state: appMachine.getCurrentState()
  });

  // Load data from storage
  const data = await loadData();
  appMachine.send('DATA_LOADED');
  setModel({
    state: appMachine.getCurrentState(),
    data
  });

  // Check if exist opened windows and initialize state machine for each one
  const windowsData = await checkOpenedWindows();
  appMachine.send('CHECK_COMPLETED');
  setModel({
    state: appMachine.getCurrentState(),
    ...model,
    ...windowsData
  });

  // Subscribe to events
  subscribeEvents();
  appMachine.send('SUBSCRIBED_TO_EVENTS');
  setModel({
    ...model,
    state: appMachine.getCurrentState()
  });
}

async function loadData() {
  // get and prepeare data
  const ids = await api.Workspaces.getIds();
  const tabs = await Promise.all(ids.map(api.Workspaces.get));
  const result = zipObject(ids, tabs);

  return {
    ...result,
    __workspaces_ids__: ids,
  };
}

async function checkOpenedWindows() {
  const windowsOpenedIDs = await api.Windows.getAll()
    .then(pipe(
      defaultTo([]),
      map(prop('id'))
    ));

  let modelsByWindowsID = {},
      machinesByWindowsID = {};

  windowsOpenedIDs.forEach(async id => {
    const machine = createMachine(createWindowStates());
    machinesByWindowsID[id] = machine;
    modelsByWindowsID[id] = {
      state: machine.getCurrentState(),
      numTabs: await api.Tabs.get(id).then(length)
    };
  });

  return {
    windowsOpenedIDs,
    modelsByWindowsID,
    machinesByWindowsID,
  };
}

function subscribeEvents() {
  chrome.windows.onCreated.addListener(handleWindowsCreated);
  chrome.extension.onMessage.addListener(handleOnMessages);
  chrome.tabs.onRemoved.addListener(handleOnTabRemoved);
  chrome.tabs.onUpdated.addListener(handleOnTabUpdated);
}

function handleOnTabUpdated(tabId, changeInfo, tab) {
  if (changeInfo.status !== 'complete') return;

  const machine = model.machinesByWindowsID[tab.windowId];
  if (machine.getCurrentState() === 'openingWorkspace') {
    setModel({
      ...model,
      modelsByWindowsID: {
        ...model.modelsByWindowsID,
        [tab.windowId]: {
          ...model.modelsByWindowsID[tab.windowId],
          numTabsOpening: model.modelsByWindowsID[tab.windowId].numTabsOpening - 1
        }
      }
    });

    const isWorkspaceOpened = (
      model.modelsByWindowsID[tab.windowId].numTabsClosing === 0
      && model.modelsByWindowsID[tab.windowId].numTabsOpening === 0
    );

    if (isWorkspaceOpened) {
      api.Tabs.get(tab.windowId).then(tabs => {
        machine.send('WORKSPACE_OPENED');
        setModel({
          ...model,
          modelsByWindowsID: {
            ...model.modelsByWindowsID,
            [tab.windowId]: {
              state: machine.getCurrentState(),
              workspaceInUse: model.modelsByWindowsID[tab.windowId].workspaceInUse,
              numTabs: length(tabs)
            }
          }
        });
      });
    }
  } else if (machine.getCurrentState() === 'workspaceInUse') {
    handleTabChanges(tab.windowId);
  }
}

function handleOnTabRemoved(tabId, { windowId, isWindowClosing }) {
  if (isWindowClosing) return;

  const machine = model.machinesByWindowsID[windowId];
  if (machine.getCurrentState() === 'openingWorkspace') {
    setModel({
      ...model,
      modelsByWindowsID: {
        ...model.modelsByWindowsID,
        [windowId]: {
          ...model.modelsByWindowsID[windowId],
          numTabsClosing: model.modelsByWindowsID[windowId].numTabsClosing - 1
        }
      }
    });

    const isWorkspaceOpened = (
      model.modelsByWindowsID[windowId].numTabsClosing === 0
      && model.modelsByWindowsID[windowId].numTabsOpening === 0
    );

    if (isWorkspaceOpened) {
      api.Tabs.get(windowId).then(tabs => {
        machine.send('WORKSPACE_OPENED');
        setModel({
          ...model,
          modelsByWindowsID: {
            ...model.modelsByWindowsID,
            [windowId]: {
              state: machine.getCurrentState(),
              workspaceInUse: model.modelsByWindowsID[windowId].workspaceInUse,
              numTabs: length(tabs)
            }
          }
        });
      });
    }
  } else if (machine.getCurrentState() === 'workspaceInUse') {
    handleTabChanges(windowId);
  }
}

function handleTabChanges(windowId) {
  api.Tabs.get(windowId).then(tabs => {
    updateCountTabsInModel(windowId)(length(tabs));

    const machine = model.machinesByWindowsID[windowId];
    const windowModel = model.modelsByWindowsID[windowId];
    const workspace = model.data[windowModel.workspaceInUse];

    api.Workspaces.update(workspace, tabs).then(function updateDataAfterOnTabCreated([id, dataSaved]) {
      machine.send('UPDATE_WORKSPACE');
      setModel({
        ...model,
        data: { ...model.data, ...dataSaved },
      });
    });
  });
}

function updateCountTabsInModel(windowId) {
  return numTabs => {
    setModel({
      ...model,
      modelsByWindowsID: {
        ...model.modelsByWindowsID,
        [windowId]: {
          ...model.modelsByWindowsID[windowId],
          numTabs
        }
      },
    });
  };
}

function handleWindowsCreated(window) {
  const { id } = window;
  const { machinesByWindowsID, modelsByWindowsID, windowsOpenedIDs } = model;
  const machine = createMachine(createWindowStates());

  setModel({
    ...model,
    machinesByWindowsID: {
      ...machinesByWindowsID,
      [id]: machine
    },
    modelsByWindowsID: {
      ...modelsByWindowsID,
      [id]: {
        state: machine.getCurrentState(),
      }
    },
    windowsOpenedIDs: [ ...windowsOpenedIDs, id ]
  });

  api.Tabs.get(id)
    .then(length)
    .then(updateCountTabsInModel(id));
}

function handleOnMessages(request, sender, sendResponse) {
  const { type, payload, window } = request;
  logMessage(type, payload, window);

  if (appMachine.getCurrentState() !== 'appLoaded') return;

  if (type === 'popup_opened' || type === 'newtab_opened') {
    broadcast(model)
  }

  if (type === 'open_chrome_page') {
    chrome.tabs.create({
      windowId: window.id,
      url: payload // "chrome://extensions/shortcuts"
    });
  }

  const machine = model.machinesByWindowsID[window.id];
  if (!machine) return;

  if (type === 'use_workspace' && machine.isEventAvailable('OPEN_WORKSPACE')) {
    machine.send('OPEN_WORKSPACE');
    setModel({
      ...model,
      modelsByWindowsID: {
        ...model.modelsByWindowsID,
        [window.id]: {
          state: machine.getCurrentState(),
          workspaceInUse: payload,
        }
      }
    });

    openWorkspace(payload, window).then(() => {});
  }

  if (type === 'create_workspace' && machine.isEventAvailable('CREATE_WORKSPACE')) {
    api.Tabs.getCurrentWindow()
      .then(tabs => api.Workspaces.save(payload, tabs))
      .then(updateModel);

    function updateModel([id, dataSaved]) {
      console.log('data saved: ', dataSaved);
      machine.send('CREATE_WORKSPACE');
      const { data, modelsByWindowsID } = model;
      setModel({
        ...model,
        data: { ...data, ...dataSaved },
        modelsByWindowsID: {
          ...modelsByWindowsID,
          [window.id]: {
            state: machine.getCurrentState(),
            workspaceInUse: id,
            numTabs: length(dataSaved[id].tabs)
          }
        }
      })
    }
  }

  if (type === 'update_workspace' && machine.isEventAvailable('UPDATE_WORKSPACE')) {
    const { tabs, ...workspace } = payload;

    // si es 0 es porque esta editando un last-sesion
    // entonces se crea un nuevo workspace en vez de actualizarlo
    if (workspace.id === 0) {
      const { id, ...rest } = workspace;
      api.Workspaces.save(rest, tabs).then(updateModel);
    } else {
      api.Workspaces.update(workspace, tabs).then(updateModel);
    }

    function updateModel([id, dataSaved]) {
      machine.send('UPDATE_WORKSPACE');
      setModel({
        ...model,
        data: { ...model.data, ...dataSaved },
      })
    }
  }

  if (type === 'delete_workspace' && machine.isEventAvailable('DELETE_WORKSPACE')) {
    api.Workspaces.remove(payload).then(workspacesIds => {
      const dataCopy = { ...model.data };
      dataCopy.__workspaces_ids__ = workspacesIds;
      delete dataCopy[payload];

      setModel({
        ...model,
        data: dataCopy
      });
    });
  }

  if (type === 'disconnect_workspace' && machine.isEventAvailable('DISCONNECT_WORKSPACE')) {
    machine.send('DISCONNECT_WORKSPACE');
    setModel({
      ...model,
      modelsByWindowsID: {
        ...model.modelsByWindowsID,
        [window.id]: {
          state: machine.getCurrentState(),
          numTabs: model.modelsByWindowsID[window.id].numTabs
        }
      }
    })
  }
}

function broadcast(model) {
  chrome.extension.sendMessage({
    type: 'MODEL_UPDATED',
    payload: model
  });
}


async function openWorkspace(workspaceId, window) {
  const getWorkspaceInUse = compose(prop('workspaceInUse'), prop(window.id), prop('modelsByWindowsID'));

  const workspaceToSave = model => {
    const workspaceInUse = getWorkspaceInUse(model);
    if (workspaceInUse) {
      return model.data[workspaceInUse];
    }
    return {
      id: 0,
      name: 'last-sesion',
      key: 'las',
      color: 'gray'
    };
  };

  const currentlyOpenTabs = await api.Tabs.get(window.id);
  const tabsToOpen = await api.Workspaces.get(workspaceId)
    .then(prop('tabs'))
    .then(map(prop('url')))
    .then(map(url => ({ windowId: window.id, url })))
    .catch(err => {
      console.warn('Error getting workspace data from storage: ', err);
    });

  setModel({
    ...model,
    modelsByWindowsID: {
      ...model.modelsByWindowsID,
      [window.id]: {
        ...model.modelsByWindowsID[window.id],
        numTabsOpening: length(tabsToOpen),
        numTabsClosing: length(currentlyOpenTabs)
      }
    }
  });

  await api.Tabs.create(tabsToOpen);
  await api.Tabs.remove(currentlyOpenTabs.map(prop('id')));

  // const [id, data] = await api.Workspaces.save(workspaceToSave(model), currentlyOpenTabs);

  return // [workspaceId, data];
}


// HELPERS

function logMachineEvent(event, currentState, newState) {
  logger
    .group(logger.templates.compose(
      logger.templates.colorText('Event'),
      logger.templates.separator(' '),
      logger.templates.chip(event, { background: '#a7a7a7', color: '#333' })
    ))
    .log(logger.templates.changed(currentState, newState))
    .log('-model-')
    .log(model)
    .time()
    .groupEnd();
}

function logMessage(type, payload, window = {}) {
  logger
    .group(logger.templates.compose(
      logger.templates.colorText('Message', '#9b59b6'),
      logger.templates.separator(' '),
      logger.templates.chip(type, { background: '#2980b9' })
    ))
    .log(`payload: ${payload}`)
    .log(`window id: ${window.id}`)
    .log(model)
    .time()
    .groupEnd();
}

