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
  createElement(root, children)
}

function render(model) {
  root({
    element: 'div', className: 'container', children: renderContent(model.workspace)
  });
}

function renderContent(currentWorkspace) {
  return currentWorkspace === undefined
    ? renderForm()
    : [{ element: 'span', textContent: currentWorkspace }];
}

function renderForm() {
  return [{
    element: 'form', children: [{
      element: 'fieldset', children: [
        { element: 'legend', textContent: 'A compact inline form' },
        { element: 'input', onChange: (e) => { inputValue = e.target.value }},
        { element: 'button', textContent: 'Save', onClick: handleClick }
      ]
    }]
  }]
}

function handleClick() {
  sendMessage({ type: 'request_to_create_a_workspace', payload: inputValue });
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

function sendMessage(msg) {
  chrome.extension.sendMessage({ ...msg, window: currentWindow });
}