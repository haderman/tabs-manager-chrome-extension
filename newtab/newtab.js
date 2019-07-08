window.onload = function() {
  chrome.extension.sendMessage({ type: 'get_workspaces' });

  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'got_workspaces':
        gotWorkspaces(request.payload);
        break;
      default:
        break;
    }
  });
}

function gotWorkspaces(workspacesList) {
  const root = document.getElementById('root');
  createElement(root,
    { element: 'div', className: 'container', children:
      renderWorkspacesList(workspacesList)
  });
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
