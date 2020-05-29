let app;

document.addEventListener("DOMContentLoaded", onLoad);

function onLoad() {
  chrome.windows.getCurrent(function gotCurrentWindow(window) {
    chrome.extension.sendMessage({ type: "newtab_opened", window });

    chrome.runtime.onMessage.addListener(
      function (message, sender, sendResponse) {
        console.log("New message: ", message.type);
        switch (message.type) {
          case "INIT_NEWTAB":
            app = Elm.NewTab.init({
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
  app.ports.openWorkspace.subscribe(function (workspaceId) {
    chrome.extension.sendMessage(
      { type: "use_workspace", payload: workspaceId, window },
    );
  });

  app.ports.updateWorkspace.subscribe(function (workspaceProxy) {
    chrome.extension.sendMessage(
      { type: "update_workspace", payload: workspaceProxy, window },
    );
  });

  app.ports.deleteWorkspace.subscribe(function (workspaceId) {
    chrome.extension.sendMessage(
      { type: "delete_workspace", payload: workspaceId, window },
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
