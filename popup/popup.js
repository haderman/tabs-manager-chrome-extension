'use-strict';

const COLORS = [
  'green',
  'blue',
  'orange',
  'purple',
  'yellow',
  'red',
  'gray',
  'cyan',
];

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
      },
      CLEAR_INPUT: 'empty'
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

document.addEventListener('DOMContentLoaded', init);

let model = {};
function setModel(newModel) {
  console.log('set model: ', newModel);
  if (model !== newModel) {
    model = newModel;
    render(view(model), document.getElementById('root'));
  }
}

function mapModel(model, func) {
  chrome.windows.getCurrent(window => {
    const getWindowsModel = compose(defaultTo({}), prop(window.id), prop('modelsByWindowsID'));
    func({
      input: {
        state: inputMachine.getCurrentState(),
        value: inputMachine.getCurrentContext(),
      },
      data: model.data,
      ...getWindowsModel(model)
    });
  });
}

function init() {
  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    if (request.type === 'MODEL_UPDATED') {
      mapModel(request.payload, setModel);
    }
  });
  
  sendMessage({ type: 'popup_opened' });
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

function view(model) {
  console.log('View: ', model);
  return (
    div({},
      section({ className: 'background-transparent zIndex-2 sticky' },
        model.state === 'started' ? viewForm(model.input, model.data) :
        model.state === 'workspaceInUse' ? viewWorkspaceInUse(model.data[model.workspaceInUse]) :
        null
      ),
      section({},
        viewWorkspacesList(model.data)
      )
    )
  )
}

function viewForm({ state, value }, data) {
  const buttonStyle = classnames(
    'background-alternate',
    'color-contrast',
    'fontSize-s',
    'padding-s',
    state === 'empty' ? 'pointerEvents-none' : ''
  );

  const inputStyle = classnames(
    'background-secondary',
    'color-contrast',
    'fontSize-s',
    'padding-s'
  );

  const handleOnClick = () => {
    if (state === 'withText') {
      sendMessage({
        type: 'create_workspace',
        payload: {
          name: value,
          key: value.substr(0, 3).toUpperCase(),
          color: getRandomItemFromArray(COLORS)
        }
      })
    }
  };

  const handleKeyUp = ({ target: { value } }) => {
    if (value.trim() === '') {
      inputMachine.send('CLEAR_INPUT');
    } else {
      inputMachine.send('NEW_INPUT_VALUE', value);
    }
    updateInputModel();
  };

  const autoFocus = dom => dom.focus();

  return (
    div({ className: 'relative' },
      viewHeader({ color: 'black' }),
      div({ className: 'grid gridTemplateCol-2 grid-col-gap-m absolute top-0 left-0 zIndex-3' },
        input({ className: inputStyle, onKeyUp: handleKeyUp, ref: autoFocus }),
        button({ className: buttonStyle, onClick: handleOnClick },
          text('Save')
        ),
      )
    )
  );
}

function viewWorkspaceInUse({ name, color }) {
  return (
    div({},
      viewHeader({ color }),
      div({ className: 'absolute top-0 left-0 zIndex-3 full-width full-height flex justifyContent-center' },
        h1({ className: `color-contrast textStroke-xs textShadow-${color}` },
          text(name)
        )
      )
    )
  ); 
}

function viewWorkspacesList(data) {
  const open = workspaceId => () => {
    sendMessage({ type: 'use_workspace', payload: workspaceId });
  };

  return (
    ul({}, ...data.__workspaces_ids__.map(workspaceId => {
      const workspace = data[workspaceId];
      if (!workspace) return;

      const buttonClassNames = classnames(
        'padding-m',
        'color-contrast',
        'fontSize-s',
        'hover',
        'flex',
        'justifyContent-center',
        'background-transparent',
        'full-width'
      );
    
      const spanClassNames = classnames(
        'flex',
        'flexDirection-col',
        'justifyContent-center',
        'alignItems-center',
        'circle',
        'backdrop',
        'width-m',
        'height-m',
        'border-l',
        `borderColor-${workspace.color}`,
        `background-${workspace.color}`,
        'relative',
        'hover-boxShadow'
      );

      return (
        button({ className: buttonClassNames, onClick: open(workspace.id) },
          span({ className: spanClassNames },
            h2({ className: 'zIndex-1' },
              text(workspace.key.substr(0, 3).toUpperCase()),
            ),
            span({ className: 'fontSize-xs fontStyle-italic zIndex-1' },
              text(workspace.name),
            ),
          ),
        )
      )
    }))
  );
}

function viewHeader(config) {
  const {
    color,
    fillOpacity = .2,
    strokeWidth = 5,
  } = config;

  return (
    div({},
      div({ className: 'absolute zIndex-1 backdrop-filter-blur support-backdrop-filter-header' }),
      svg({ viewBox: '5 105 170 100', class: 'relative zIndex-2' },
        svg.path(
          { class: `fill-${color} stroke-${color}`,
            fill_opacity: fillOpacity,
            stroke_width: strokeWidth,
            d: 'M0,0C0,0,0,171.14385,0,171.14385C24.580441,186.61523,55.897012,195.90157,90,195.90157C124.10299,195.90157,155.41956,186.61523,180,171.14385C180,171.14385,180,0,180,0C180,0,0,0,0,0C0,0,0,0,0,0',
          },
        )
      )
    )
  );
}

// HELPERS

function sendMessage(msg) {
  chrome.windows.getCurrent(window => {
    chrome.extension.sendMessage({ ...msg, window });
  });
}

function getRandomItemFromArray(arr) {
  const lenght = arr.length - 1;
  const randomIndex = Math.floor(Math.random() * lenght);
  return arr[randomIndex];
}