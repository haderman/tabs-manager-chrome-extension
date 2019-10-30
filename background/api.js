/**
 * @typedef {Object} Workspace
 * @property {string} name name of workspace
 * @property {string} key
 * @property {string} color
 * 
 * @typedef {Object} Tab
 * @property {string} title
 */

const api = {
  Workspaces: {
    /**
     * @param {Workspace} workspace to save.
     * @param {string} workspace.name name of workspace
     * @param {Array.<Tab>} tabs
     * @returns {Object} data saved
     */
    save: ({ name, key, color }, tabs) =>
      api.Workspaces.getNames()
        .then(names => ({
          [name]: { tabs, name, key, color },
          __workspaces_names__: [name, ...names].filter(onlyUnique)
        }))
        .then(async data => {
          await chromePromise.storage.sync.set(data);
          return data;
        }),

    get: name =>
      chromePromise.storage.sync.get(name)
        .then(prop(name)),

    getNames: () =>
      chromePromise.storage.sync.get('__workspaces_names__')
        .then(prop('__workspaces_names__'))
        .then(defaultTo([])),
  },
  Tabs: {
    get: windowId =>
      chromePromise.tabs.query({ windowId })
        .then(map(pick(['title', 'url', 'favIconUrl', 'id']))),

    getCurrentWindow: () =>
      chromePromise.tabs.query({ currentWindow: true })
        .then(map(pick(['title', 'url', 'favIconUrl']))),

    remove: arrOfTabsIds =>
      chromePromise.tabs.remove(arrOfTabsIds),

    create: tabs =>
      Array.isArray(tabs)
        ? Promise.all(tabs.map(tab => chromePromise.tabs.create(tab)))
        : chromePromise.tabs.create(tab),
  },
  Windows: {
    getAll: () =>
      chromePromise.windows.getAll()
  }
};