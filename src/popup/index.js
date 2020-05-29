let app;

document.addEventListener("DOMContentLoaded", onLoad);

function onLoad() {
  chrome.windows.getCurrent(function gotCurrentWindow(window) {
    chrome.extension.sendMessage({ type: "popup_opened", window });

    chrome.runtime.onMessage.addListener(
      function (message, sender, sendResponse) {
        console.log("New message: ", message.type);
        switch (message.type) {
          case "INIT_POPUP":
            app = Elm.Popup.init({
              node: document.getElementById("elm"),
              flags: {
                data: prepareModel(message.payload, window),
              },
            });
            subscribePorts(window);
            break;
          case "MODEL_UPDATED":
            const model = prepareModel(message.payload, window);
            console.log("payload: ", model);

            app.ports.receivedDataFromJS.send({
              data: {
                ...model,
                // workspaces: [],
                // status: {
                //   state: 'noData'
                // }
              },
            });
            break;
        }
      },
    );
  });
}

function subscribePorts(window) {
  app.ports.openWorkspace.subscribe((workspaceId) => {
    chrome.extension.sendMessage(
      { type: "use_workspace", payload: workspaceId, window },
    );
  });

  app.ports.createWorkspace.subscribe(([name, color]) => {
    const payload = { name, color };
    chrome.extension.sendMessage(
      { type: "create_workspace", payload, window },
    );
  });

  app.ports.openChromePage.subscribe((url) => {
    chrome.extension.sendMessage(
      { type: "open_chrome_page", payload: url, window },
    );
  });

  app.ports.disconnectWorkspace.subscribe(() => {
    chrome.extension.sendMessage({ type: "disconnect_workspace", window });
  });

  app.ports.changeTheme.subscribe((theme) => {
    chrome.extension.sendMessage(
      { type: "change_theme", payload: theme, window },
    );
  });
}

function prepareModel(model, window) {
  console.log(model);
  const { modelsByWindowsID, data } = model;
  const { __workspaces_ids__, __settings__, ...workspacesInfo } = data;
  return {
    workspaces: __workspaces_ids__.filter((i) => i !== null),
    workspacesInfo: workspacesInfo,
    status: modelsByWindowsID[window.id],
    numTabs: modelsByWindowsID[window.id].numTabs,
    settings: __settings__,
  };
}
