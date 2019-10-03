
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
  
  console.log('GET MODEL');
  setTimeout(() => {
    sendMessage({ type: 'get_model' });
  }, 100);
}

function render(model) {
  console.log('Render: ', model);
  root({ element: 'div', children: renderContent(model) });
}

function renderContent(model) {
  return [{
    element: 'ul',
    className: 'padding-m',
    children: model.data.__workspaces_names__.map(workspaceName => ({
      element: 'li',
      className: 'hover',
      children: [{
        element: 'div',
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
          onClick: () => sendMessage({ type: 'use_workspace', payload: workspaceName }),
        }]
      }, {
        element: 'div',
        children: model.data[workspaceName].tabs.map(tab => ({
          element: 'img',
          className: classnames(
            'width-s',
            'height-s',
            'beforeBackgroundColor-secondary',
            'marginRight-s',
          ),
          src: tab.favIconUrl,
          // textContent: tab.title
        }))
      }],
    }))
  }];
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
  const { children, onClick, ...rest } = node;

  if (onClick) {
    $element.onclick = onClick;
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