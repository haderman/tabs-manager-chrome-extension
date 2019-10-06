'use strict';

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
  const ROOT = document.getElementById('root');
  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'MODEL_UPDATED':
        mapModel(request.payload, model => {
          render(view(model), ROOT);
        });
      default:
        break;
    }
  });
  
  console.log('GET MODEL');
  setTimeout(() => {
    sendMessage({ type: 'get_model' });
  }, 100);
}

function view(model) {
  function openButton(workspaceName) {
    const style = classnames(
      'padding-m',
      'background-transparent',
      'marginLeft-l',
      'marginBottom-xs',
      'color-alternate',
      'show-in-hover',
    );
    const onClick = () => sendMessage({ type: 'use_workspace', payload: workspaceName });
    return (
      button({ className: style, onClick },
        text('Open')
      )
    );
  }
  
  return (
    ul({ className: 'padding-m'}, ...model.data.__workspaces_names__.map(name =>
      li({ className: 'hover' },
        div({},
          h2({ className: 'color-contrast inline '},
            text(name)
          ),
          openButton(name)
        ),
        div({}, ...model.data[name].tabs.map(tab =>
          img({
            src: tab.favIconUrl,
            className: classnames(
              'width-s',
              'height-s',
              'beforeBackgroundColor-secondary',
              'marginRight-s',
            ),
          })
        ))
      )  
    ))
  );
}

function sendMessage(msg) {
  chrome.windows.getCurrent(window => {
    chrome.extension.sendMessage({ ...msg, window });
  });
}