function onLoad() {
  chrome.windows.getCurrent(function gotCurrentWindow(window) {
    app = Elm.Popup.init({
      node: document.getElementById('elm'),
      flags: { window: window.id }
    });

    chrome.extension.sendMessage({ type: 'popup_opened', window });

    chrome.runtime.onMessage.addListener(
      function(message, sender, sendResponse) {
        switch (message.type) {
        case 'MODEL_UPDATED':
          const { modelsByWindowsID, data } = message.payload;
          const { __workspaces_ids__, ...workspacesInfo } = data;
          const payload = {
            workspaces: __workspaces_ids__.filter(i => i !== null),
            workspacesInfo: workspacesInfo,
            status: modelsByWindowsID[window.id],
            numTabs: modelsByWindowsID[window.id].numTabs
          }
          console.log('payload: ', payload)
          app.ports.receivedDataFromJS.send({
            data: payload
          });
          return;
        }
      }
    );

    app.ports.openWorkspace.subscribe(function (workspaceId) {
      chrome.extension.sendMessage({ type: 'use_workspace', payload: workspaceId, window });
    });

    app.ports.createWorkspace.subscribe(function ([name, color]) {
      const payload = { name, color }
      chrome.extension.sendMessage({ type: 'create_workspace', payload, window });
    });
  });
}

document.addEventListener('DOMContentLoaded', function() {
  onLoad();
});
