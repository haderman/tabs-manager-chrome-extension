function onLoad() {
  chrome.windows.getCurrent(function gotCurrentWindow(window) {
    app = Elm.Main.init({
      node: document.getElementById('elm'),
      flags: { window: window.id }
    });

    chrome.extension.sendMessage({ type: 'newtab_opened', window });

    chrome.runtime.onMessage.addListener(
      function(message, sender, sendResponse) {
        switch (message.type) {
        case 'MODEL_UPDATED':
          console.log('model updated: ', message.payload);
          const { modelsByWindowsID, data } = message.payload;
          const { __workspaces_ids__, ...workspacesInfo } = data;
          app.ports.receivedDataFromJS.send({
            data: {
              workspaces: __workspaces_ids__.filter(i => i !== null),
              workspacesInfo: workspacesInfo,
              status: modelsByWindowsID[window.id]
            }
          });
          return;
        }
      }
    );

    app.ports.openWorkspace.subscribe(function (workspaceId) {
      chrome.extension.sendMessage({ type: 'use_workspace', payload: workspaceId, window });
    });

    app.ports.updateWorkspace.subscribe(function (workspaceProxy) {
      chrome.extension.sendMessage({ type: 'update_workspace', payload: workspaceProxy, window });
    });

    app.ports.deleteWorkspace.subscribe(function (workspaceId) {
      chrome.extension.sendMessage({ type: 'delete_workspace', payload: workspaceId, window });
    });
  }); 
}

document.addEventListener('DOMContentLoaded', function() {
  onLoad();
});