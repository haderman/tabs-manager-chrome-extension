let currentWindow;

function selectCurrentWindowModel(model, currentWindow) {
  return { ...model, ...model.windows[currentWindow.id] }
}

window.onload = function onLoad() {
  chrome.windows.getCurrent(window => {
    currentWindow = window;
    init();
  });
};


function init() {
  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'MODEL_UPDATED':
        console.log('MODEL_UPDATED');
        render(selectCurrentWindowModel(request.payload, currentWindow));
      default:
        break;
    }
  });
  
  console.log('GET MODEL');
  setTimeout(() => {
    sendMessage({ type: 'get_model' });
  }, 100);
}

function render(model) {
  root({ element: 'div', children: renderContent(model) });
}

function root(children) {
  const root = document.getElementById('root');
  while (root.firstChild) {
    root.removeChild(root.firstChild);
  }
  createElement(root, children);
}

function renderContent(model) {
  return [{
    element: 'ul',
    className: 'padding-m',
    children: model.workspaces.map(workspaceName => ({
      element: 'li',
      className: 'hover',
      children: [{
        element: 'h2',
        className: 'color-contrast inline',
        textContent: workspaceName,
      }, {
        element: 'button',
        className: classnames(
          'padding-m',
          'background-transparent',
          'marginLeft-l',
          'marginBottom-xs',
          'color-alternate',
          'show-in-hover',
          ),
        textContent: 'Open',
        onClick: openWorkspace(workspaceName),
      }]
    }))
  }];
}

function openWorkspace(ws) {
  return () => {
    sendMessage({ type: 'request_to_open_workspace', payload: ws });
  };
}



// HELPERS


function createElement(parent, node) {
  const $element = document.createElement(node.element);
  const { className, children, textContent, onClick } = node;
  
  if (className !== undefined) {
    $element.className = node.className;
  }

  if (textContent !== undefined) {
    $element.textContent = textContent;  
  }

  if (onClick !== undefined) {
    $element.onclick = onClick;
  }

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
  chrome.runtime.sendMessage({ ...msg, window: currentWindow });
}