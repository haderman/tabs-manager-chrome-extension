function onLoad() {
  chrome.windows.getCurrent(function gotCurrentWindow(window) {
    app = Elm.NewTab.init({
      node: document.getElementById('elm')
    });

    chrome.extension.sendMessage({ type: 'newtab_opened', window });

    chrome.runtime.onMessage.addListener(
      function(message, sender, sendResponse) {
        switch (message.type) {
        case 'MODEL_UPDATED':
          const { modelsByWindowsID, data } = message.payload;
          const { __workspaces_ids__, __settings__, ...workspacesInfo } = data;
          const payload = {
            workspaces: __workspaces_ids__.filter(i => i !== null),
            workspacesInfo: workspacesInfo,
            status: modelsByWindowsID[window.id],
            numTabs: modelsByWindowsID[window.id].numTabs,
            settings: __settings__
          }
          console.log('payload: ', payload)
          app.ports.receivedDataFromJS.send({
            data: {
              ...payload,
              // workspaces: [],
              // status: {
              //   state: 'noData'
              // }
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
