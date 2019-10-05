function createMachine(states, actions) {
  let currentState = states.initial;
  let currentContext = states.context;

  const _setState = state => {
    console.log(`%c${currentState} %c-> %c${state}`,
      'color:gray', 'color:white', 'color:green');
    currentState = state;
  };

  const _isEventAvailable = event => event in states[currentState].on;

  const _handleEventValue = (event, value) => {
    const eventValue = states[currentState].on[event];

    if (typeof eventValue === 'string') {
      return eventValue;
    }

    eventValue.actions.forEach(action => {
      currentContext = actions[action](currentContext, event, value); 
    });
    return eventValue.target;
  };

  return {
    send(event, value) {
      if (_isEventAvailable(event)) {
        console.group('event: ', event);
        const nextState = _handleEventValue(event, value);
        _setState(nextState);
        console.groupEnd();
      }
      return currentState;
    },
    isEventAvailable(event) {
      return _isEventAvailable(event);
    },
    getCurrentState() {
      return currentState;
    },
    getCurrentContext() {
      return currentContext;
    },
  };
}

const inputStates = {
  initial: 'empty',
  context: '',
  empty: {
    on: {
      NEW_INPUT_VALUE: {
        target: 'withText',
        actions: ['updateValue']
      }
    }
  },
  withText: {
    on: {
      NEW_INPUT_VALUE: {
        target: 'withText',
        actions: ['updateValue']
      }
    }
  }
}; 

const inputActions = {
  updateValue: (context, event, value) => {
    return value;
  }
};

const inputMachine = createMachine(inputStates, inputActions);


// temporal
let inputValue = '';

window.onload = init;

let model = {};
function setModel(newModel) {
  console.log('set model: ', newModel);
  if (model !== newModel) {
    model = newModel;
    render(model);
  }
}

function mapModel(model, func) {
  chrome.windows.getCurrent(window => {
    func({
      input: {
        state: inputMachine.getCurrentState(),
        value: inputMachine.getCurrentContext(),
      },
      data: model.data,
      ...model.modelsByWindowsID[window.id],
    });
  });
}

function init() {
  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    if (request.type === 'MODEL_UPDATED') {
      mapModel(request.payload, setModel);
    }
  });
  
  sendMessage({ type: 'get_model' });
}

function updateInputModel() {
  setModel({
    ...model,
    input: {
      state: inputMachine.getCurrentState(),
      value: inputMachine.getCurrentContext()
    }
  });
}

function render(model) {
  console.log('Render: ', model);
  root({
    element: 'div',
    children: [{
      element: 'div',
      className: 'color-contrast',
      textContent: model.input.state
    }, {
      element: 'section',
      className: 'background-primary',
      children: [
        model.state === 'started' ? viewForm(model.input) :
        model.state === 'workspaceInUse' ? viewWorkspaceName(model.workspaceNameInUse) :
        null
      ]
    }, {
      element: 'section',
      children: [{
        element: 'h3',
        className: 'color-contrast',
        textContent: 'YOUR WORKSPACES',
      },
        viewWorkspacesList(model.data.__workspaces_names__)
      ]
    }]
  });
}

function viewWorkspaceName(name) {
  return {
    element: 'h1',
    className: 'color-alternate textAlign-center',
    textContent: name,
  };
}

function viewForm({ state, value }) {
  return {
    element: 'div',
    className: 'grid grid-template-col-2 grid-col-gap-m',
    children: [{
      element: 'input',
      className: classnames(
        'background-secondary',
        'color-contrast',
        'fontSize-s',
        'padding-s'
      ),
      value,
      onChange: (e) => {
        inputMachine.send('NEW_INPUT_VALUE', e.target.value);
      },
      onKeyUp: (e) => {
        inputMachine.send('NEW_INPUT_VALUE', e.target.value);
        updateInputModel();
      }
    }, {
      element: 'button',
      className: classnames(
        'background-alternate',
        'color-contrast',
        'fontSize-s',
        'padding-s',
        state === 'empty' ? 'pointerEvents-none' : ''
      ),
      textContent: 'Save',
      onClick: () => {
        if (state === 'withText') {
          // sendMessage({ type: 'create_workspace', payload: inputValue })
        }
      },
    }]
  };
}

function viewWorkspacesList(workspacesList) {
  const action = (text, func) => ({
    element: 'button',
    className: classnames(
      'padding-xs',
      'marginLeft-m',
      'fontSize-xs',
      'rounded',
      'border-s',
      'borderColor-alternate',
      'color-alternate',
      'background-transparent'
    ),
    textContent: text,
    onClick: func,
  });

  return {
    element: 'ul',
    children: workspacesList.map(workspaceName => ({
      element: 'li',
      className: 'padding-m color-contrast fontSize-s hover',
      children: [{
        element: 'span',
        className: 'fontSize-m',
        textContent: workspaceName,
      }, {
        element: 'span',
        className: 'marginLeft-xl show-in-hover',
        children: [
          action('Save', () => { console.log('SAve ')}),
          action('Open', () => sendMessage({
            type: 'use_workspace',
            payload: workspaceName
          }))
        ]
      }
    ]  
    }))
  };
}



// HELPERS

function root(children) {
  const root = document.getElementById('root');
  while (root.firstChild) {
    root.removeChild(root.firstChild);
  }
  createElement(root, children);
}

function createElement(parent, node) {
  const $element = document.createElement(node.element);
  const { children, onClick, onChange, onKeyUp, ...rest } = node;

  if (onClick) {
    $element.onclick = onClick;
  }

  if (onChange) {
    $element.onchange = onChange;
  }

  if (onKeyUp) {
    $element.onkeyup = onKeyUp;
  }

  Object.keys(rest).forEach(key => {
    $element[key] = rest[key];
  });

  if (children !== undefined) {
    node.children.forEach(child => {
      createElement($element, child);
    });  
  }

  parent.appendChild($element);
}

function classnames(...args) {
  return args.join(' ');
}

function sendMessage(msg) {
  chrome.windows.getCurrent(window => {
    chrome.extension.sendMessage({ ...msg, window });
  });
}