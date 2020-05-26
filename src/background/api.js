import ChromePromise from "./chrome-promise.js";
import * as fp from "./fp.js";

const chromePromise = new ChromePromise();

/**
 * @typedef {Object} Workspace
 * @property {string} name name of workspace
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
    save: ({ id, name, color }, tabs) =>
      api.Workspaces.getIds()
        .then((ids) => {
          const id_ = id === undefined ? generateId(ids) : id;
          return [
            id_,
            {
              [id_]: { tabs, name, color, id: id_ },
              __workspaces_ids__: [id_, ...ids].filter(fp.onlyUnique),
            },
          ];
        })
        .then(async ([id, data]) => {
          await chromePromise.storage.sync.set(data);
          return [id, data];
        }),
    async remove(id) {
      await chromePromise.storage.sync.remove(id.toString());
      const ids = await api.Workspaces.getIds();
      const filteredIds = ids.filter((id_) => id !== id_);
      await chromePromise.storage.sync.set({ __workspaces_ids__: filteredIds });
      return filteredIds;
    },
    update: async ({ id, name, color }, tabs) => {
      if (id === undefined) {
        throw "Error in update workspace, id is undefined";
      }

      const data = {
        [id]: { tabs, name, color, id: id },
      };

      await chromePromise.storage.sync.set(data);
      return [id, data];
    },
    get: (id) =>
      chromePromise.storage.sync.get(id.toString())
        .then(fp.prop(id)),

    getIds: () =>
      chromePromise.storage.sync.get("__workspaces_ids__")
        .then(fp.prop("__workspaces_ids__"))
        .then(fp.defaultTo([])),
  },
  Tabs: {
    get: (windowId) =>
      chromePromise.tabs.query({ windowId })
        .then(fp.map(fp.pick(["title", "url", "favIconUrl", "id"]))),

    getCurrentWindow: () =>
      chromePromise.tabs.query({ currentWindow: true })
        .then(fp.map(fp.pick(["title", "url", "favIconUrl"]))),

    remove: (arrOfTabsIds) => chromePromise.tabs.remove(arrOfTabsIds),

    create: (tabs) =>
      Array.isArray(tabs)
        ? Promise.all(tabs.map((tab) => chromePromise.tabs.create(tab)))
        : chromePromise.tabs.create(tab),
  },
  Windows: {
    getAll: () => chromePromise.windows.getAll(),
  },
  Settings: {
    _set: async (newSettings) => {
      const settings = await api.Settings.get();
      await chromePromise.storage.sync.set(
        { __settings__: { ...settings, ...newSettings } },
      );
      return api.Settings.get();
    },
    get: () => {
      return chromePromise.storage.sync.get("__settings__")
        .then(fp.prop("__settings__"))
        .then(fp.defaultTo({ theme: "dark" }));
    },
    setTheme: (theme) => {
      return api.Settings._set({ theme });
    },
  },
};

function generateId(idsInUse = []) {
  if (idsInUse.length === 0) return 1;
  else return Math.max(...idsInUse) + 1;
}

export default api;
