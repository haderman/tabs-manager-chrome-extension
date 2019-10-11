'use strict';

function sendMessage(msg) {
  chrome.windows.getCurrent(window => {
    chrome.extension.sendMessage({ ...msg, window });
  });
}

function mapModel(model, func) {
  chrome.windows.getCurrent(window => {
    const getWindowsModel = compose(defaultTo({}), prop(window.id), prop('modelsByWindowsID'));
    func({
      data: model.data,
      ...getWindowsModel(model)
    });
  });
}

window.onload = function init() {
  console.log('init');
  const ROOT = document.getElementById('root');
  chrome.extension.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
      case 'MODEL_UPDATED':
        mapModel(request.payload, model => {
          console.log('View: ', model);
          render(view(model), ROOT);
        });
      default:
        break;
    }
  });
  
  setTimeout(() => {
    sendMessage({ type: 'newtab_opened' });
  }, 100);
};

function view(model) {
  const getWorkspaces = pipe(
    prop('data'),
    prop('__workspaces_names__'),
    defaultTo([])
  );

  const style = classnames(
    'grid',
    'gridTemplateCol-repeat-xl',
    'gridGap-m',
    'padding-m',
    'justifyContent-center',
  );

  return (
    div({ className: style },
      ...getWorkspaces(model).map(name => viewWorkspaceCard(name, model.data)
    ))
  );
}

function viewWorkspaceCard(workspaceName, data) {
  const getTabs = pipe(
    prop(workspaceName),
    prop('tabs'),
    defaultTo([])
  );

  const containerStyle = classnames(
    'padding-m',
    'border-s',
    'rounded',
    'borderColor-secondary',
    'width-xl',
    'height-fit-content'
  );

  const titleStyle = classnames(
    'ellipsis',
    'overflowHidden',
    'whiteSpace-nowrap',
    'color-contrast',
  );
  
  const divider = () => div({ className: classnames(
    'marginBottom-m',
    'borderBottom-s',
    'borderColor-secondary',
  )});

  return (
    div({ className: containerStyle },
      div({ className: 'flex alignItems-center justifyContent-space-between' },
        h3({ className: 'color-alternate marginTop-none' },
          text(workspaceName),
        ),
        viewButton({
          label: 'Open',
          onClick: () => sendMessage({ type: 'use_workspace', payload: workspaceName })
        })
      ),
      divider(),
      ...getTabs(data).map(tab =>
        div({ className: 'flex alignItems-center marginBottom-s' },
          img({
            src: tab.favIconUrl,
            className: classnames(
              'width-xs',
              'height-xs',
              'beforeBackgroundColor-secondary',
              'marginRight-s',
            ),
          }),
          span({ className: titleStyle },
            text(tab.title)
          )
        )
      )
    )
  );
}

function viewButton({ label, onClick }) {
  const style = classnames(
    'padding-m',
    'background-secondary',
    'rounded',
    'marginLeft-l',
    'marginBottom-xs',
    'color-contrast',
    'show-in-hover'
  );
  
  return (
    button({ className: style, onClick },
      text(label)
    )
  );
}
