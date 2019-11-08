'use strict';

const chromePromise = new ChromePromise();
const logger = createLogger();

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

const windowStates = {
  initial: 'started',
  started: {
    on: {
      OPEN_WORKSPACE: 'workspaceInUse',
      CREATE_WORKSPACE: 'workspaceInUse'
    }
  },
  workspaceInUse: {
    on: {
      OPEN_WORKSPACE: 'workspaceInUse'
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

let model = {
  idsOfWindowsOpened: [],
  machinesByWindowsID: {},
  data: {}
};

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
  const names = await api.Workspaces.getNames();
  const tabs = await Promise.all(names.map(api.Workspaces.get));
  const result = zipObject(names, tabs);

  return {
    ...result,
    __workspaces_names__: names,
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
      
  windowsOpenedIDs.forEach(id => {
    const machine = createMachine(windowStates);
    machinesByWindowsID[id] = machine;
    modelsByWindowsID[id] = { state: machine.getCurrentState() };
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
}

function handleWindowsCreated(window) {
  const { id } = window;
  const { machinesByWindowsID, modelsByWindowsID, windowsOpenedIDs } = model;
  const machine = createMachine(windowStates);
  setModel({
    ...model,
    machinesByWindowsID: {
      ...machinesByWindowsID,
      [id]: machine
    },
    modelsByWindowsID: {
      ...modelsByWindowsID,
      [id]: {
        state: machine.getCurrentState()
      }
    },
    windowsOpenedIDs: [ ...windowsOpenedIDs, id ]
  });
}

function handleOnMessages(request, sender, sendResponse) {
  const { type, payload, window } = request;
  logMessage(type, payload, window);
  
  if (appMachine.getCurrentState() !== 'appLoaded') return;

  if (type === 'popup_opened' || type === 'newtab_opened') {
    broadcast(model)
  }

  const machine = model.machinesByWindowsID[window.id];
  if (!machine) return;

  if (type === 'use_workspace' && machine.isEventAvailable('OPEN_WORKSPACE')) {
    openWorkspace(payload, window).then(prevWorkspaceData => {
      machine.send('OPEN_WORKSPACE');
      setModel({
        ...model,
        data: {
          ...model.data,
          ...prevWorkspaceData
        },
        modelsByWindowsID: {
          ...model.modelsByWindowsID,
          [window.id]: {
            state: machine.getCurrentState(),
            workspaceInUse: model.data[payload],
          }
        }
      });
    });
  }

  if (type === 'create_workspace' && machine.isEventAvailable('CREATE_WORKSPACE')) {
    api.Tabs.getCurrentWindow()
      .then(tabs => api.Workspaces.save(payload, tabs))
      .then(dataSaved => {
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
              workspaceInUse: payload
            }
          }
        })
      });
  }
}

function broadcast(model) {
  chrome.extension.sendMessage({
    type: 'MODEL_UPDATED',
    payload: model
  });
}


async function openWorkspace(workspaceName, window) {
  const getCurrentWorkspace = pipe(
    prop('modelsByWindowsID'),
    prop(window.id),
    prop('workspaceInUse'),
    defaultTo({
      name: 'last-sesion',
      key: 'las',
      color: 'gray'
    }),
  );
  
  const currentlyOpenTabs = await api.Tabs.get(window.id);
  const tabsToOpen = await api.Workspaces.get(workspaceName)
    .then(prop('tabs'))
    .then(map(prop('url')))
    .then(map(url => ({ windowId: window.id, url })))
    .catch(err => {
      console.warn('Error getting workspace data from storage: ', err);
    });
  
  await api.Tabs.create(tabsToOpen);
  await api.Tabs.remove(currentlyOpenTabs.map(prop('id')));
  
  const {
    __workspaces_names__,
    ...rest
  } = await api.Workspaces.save(getCurrentWorkspace(model), currentlyOpenTabs);
  
  return rest;
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
