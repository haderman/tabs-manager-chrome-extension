// temporal
let inputValue = '';

let currentWindow;

function selectCurrentWindowModel(model, currentWindow) {
  return { ...model, ...model.windows[currentWindow.id] }
}

window.onload = function onLoad() {
  chrome.windows.getCurrent(window => {
    currentWindow = window;
    init(currentWindow);
  });
};

function init() {
  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'MODEL_UPDATED':
        render(selectCurrentWindowModel(request.payload, currentWindow));
      default:
        break;
    }
  });
  
  sendMessage({ type: 'get_model' });
}

function root(children) {
  const root = document.getElementById('root');
  while (root.firstChild) {
    root.removeChild(root.firstChild);
  }
  createElement(root, children)
}

function render(model) {
  root({
    element: 'div',
    children: [{
      element: 'section',
      className: 'background-secondary',
      children: [
        model.workspace === undefined ? viewForm() : viewWorkspace(model)
      ]
    }, {
      element: 'section',
      children: [{
        element: 'h3',
        className: 'color-contrast',
        textContent: 'YOUR WORKSPACES',
      },
        viewWorkspacesList(model.workspaces)
      ]
    }]
  });
}

function viewWorkspace(model) {
  return {
    element: 'h1',
    className: 'color-alternate textAlign-center',
    textContent: model.workspace,
  };
}

function viewForm() {
  return {
    element: 'div',
    className: 'grid grid-template-col-2 grid-col-gap-m',
    children: [{
      element: 'input',
      className: classnames(
        'background-secondary',
        'color-contrast',
        'borderBottomColor-contrast',
        'fontSize-s',
        'padding-s'
      ),
      onChange: (e) => { inputValue = e.target.value },
    }, {
      element: 'button',
      className: classnames(
        'background-alternate',
        'color-contrast',
        'fontSize-s',
        'padding-s'
      ),
      textContent: 'Save',
      onClick: () => sendMessage({ type: 'request_to_create_a_workspace', payload: inputValue }),
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
      'background-hidden'
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
          action('Save', () => {}),
          action('Open', () => sendMessage({ type: 'request_to_open_workspace', payload: workspaceName }))
        ]
      }
    ]  
    }))
  };
}



// HELPERS

function createElement(parent, node) {
  const { element, className, children, textContent, onClick, onChange } = node;
  
  const $element = document.createElement(element);
  
  if (className !== undefined) {
    $element.className = node.className;
  }

  if (textContent !== undefined) {
    $element.textContent = textContent;  
  }

  if (onClick !== undefined) {
    $element.onclick = onClick;
  }

  if (onChange !== undefined) {
    $element.onchange = onChange;
  }

  if (children !== undefined) {
    node.children.forEach(child => createElement($element, child));  
  }

  parent.appendChild($element);
}

function classnames(...args) {
  return args.join(' ');
}

function sendMessage(msg) {
  chrome.extension.sendMessage({ ...msg, window: currentWindow });
}