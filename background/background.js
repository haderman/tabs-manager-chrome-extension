'use strict';

const chromePromise = new ChromePromise();

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

function createMachineV2(states) {
  let currentState = states.initial;
  
  const _setState = state => {
    console.log(`%c${currentState} %c-> %c${state}`,
      'color:gray', 'color:white', 'color:green');
    currentState = state;
  };

  const _isEventAvailable = event => event in states[currentState].on;

  return {
    send(event) {
      if (_isEventAvailable(event)) {
        console.group('event: ', event);
        _setState(states[currentState].on[event]);
        console.groupEnd();
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

let model = {
  idsOfWindowsOpened: [],
  machinesByWindowsID: {},
  data: {}
};

function setModel(newModelV2) {
  if (model !== newModelV2) {
    model = newModelV2;
    console.log('NEW MODEL: ', model);
    broadcast(model);
  }
} 

const appMachine = createMachineV2(appStates);

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
    const machine = createMachineV2(windowStates);
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
  const machine = createMachineV2(windowStates);
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
    
    if (type === 'get_model' && appMachine.getCurrentState() === 'appLoaded') {
      broadcast(model);
    }

    const machine = model.machinesByWindowsID[window.id];
    if (!machine) return;

    if (type === 'use_workspace' && machine.isEventAvailable('OPEN_WORKSPACE')) {
      openWorkspace(payload, window);
      machine.send('OPEN_WORKSPACE');
      setModel({
        ...model,
        modelsByWindowsID: {
          ...model.modelsByWindowsID,
          [window.id]: {
            state: machine.getCurrentState(),
            workspaceNameInUse: payload,
          }
        }
      });
    }

    if (type === 'create_workspace' && machine.isEventAvailable('CREATE_WORKSPACE')) {
      api.Tabs.getCurrentWindow()
        .then(tabs => api.Workspaces.save(payload, tabs))
        .then(dataSaved => {
          machine.send('CREATE_WORKSPACE');
          const { data, modelsByWindowsID } = model;
          setModel({
            ...model,
            data: { ...data, ...dataSaved },
            modelsByWindowsID: {
              ...modelsByWindowsID,
              [window.id]: {
                state: machine.getCurrentState(),
                workspaceNameInUse: payload
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
    prop('windows'),
    prop(window.id),
    prop('workspace'),
    defaultTo('last-sesion'),
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
  
  const workspaceSaved = await api.Workspaces.save(getCurrentWorkspace(model), currentlyOpenTabs);
  
  setModel({
    ...model,
    ...workspaceSaved,
    windows: {
      [window.id]: {
        workspace: workspaceName
      }
    }
  });
}

