// temporal
let inputValue = '';

window.onload = init;

function mapModel(model, func) {
  chrome.windows.getCurrent(window => {
    func({
      data: model.data,
      ...model.modelsByWindowsID[window.id]
    });
  });
}

function init() {
  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'MODEL_UPDATED':
        mapModel(request.payload, render);
      default:
        break;
    }
  });
  
  sendMessage({ type: 'get_model' });
}

function render(model) {
  console.log('Render: ', model);
  root({
    element: 'div',
    children: [{
      element: 'div',
      className: 'color-contrast',
      textContent: model.state
    }, {
      element: 'section',
      className: 'background-primary',
      children: [
        model.state === 'started' ? viewForm() :
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

function viewForm() {
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
      onClick: () => {
        if (inputValue !== '') {
          sendMessage({ type: 'create_workspace', payload: inputValue })
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
  createElement(root, children)
}

function createElement(parent, node) {
  const $element = document.createElement(node.element);
  const { children, onClick, onChange, ...rest } = node;

  if (onClick) {
    $element.onclick = onClick;
  }

  if (onChange) {
    $element.onchange = onChange;
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