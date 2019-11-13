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
    save: ({ id, name, key, color }, tabs) =>
      api.Workspaces.getIds()
        .then(ids => {
          const id_ = id || generateId(ids);
          return [
            id_, 
            {
              [id_]: { tabs, name, key, color, id: id_ },
              __workspaces_ids__: [id_, ...ids].filter(onlyUnique)
            }
          ]
        })
        .then(async ([id, data]) => {
          await chromePromise.storage.sync.set(data);
          return [id, data];
        }),
    update: async ({ id, name, key, color }, tabs) => {
      if (!id) return;
      const data = {
        [id]: { tabs, name, key, color, id: id }
      };
      await chromePromise.storage.sync.set(data);
      return [id, data];
    },
    get: id =>
      chromePromise.storage.sync.get(id.toString())
        .then(prop(id)),

    getIds: () =>
      chromePromise.storage.sync.get('__workspaces_ids__')
        .then(prop('__workspaces_ids__'))
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

function generateId(idsInUse = []) {
  if (idsInUse.length === 0) return 1;
  else return Math.max(...idsInUse) + 1;
}