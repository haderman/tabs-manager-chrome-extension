window.onload = function() {
  chrome.extension.sendMessage({ type: 'get_model' });

  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'MODEL_UPDATED':
        render(request.payload);
      default:
        break;
    }
  });
}


function render(model) {
  root({
    element: 'div', className: 'container', children: renderWorkspacesList(model.workspaces)
  });
}

function root(children) {
  const root = document.getElementById('root');
  createElement(root, children)
}

function renderWorkspacesList(workspacesList) {
  const button = ws => ({ element: 'button', textContent: ws, onClick: openWorkspace(ws) });
  return workspacesList.map(button);
}

function openWorkspace(ws) {
  return () => {
    chrome.extension.sendMessage({ type: 'open_workspace', payload: ws });
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
