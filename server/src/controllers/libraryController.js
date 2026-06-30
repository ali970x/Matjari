const store = require('../services/store');
const asyncHandler = require('../utils/asyncHandler');
const { httpError } = require('../utils/httpError');

const listMyApps = asyncHandler(async (req, res) => {
  const apps = store
    .all('user_apps')
    .filter((item) => item.user_id === req.user.id)
    .map((entry) => ({
      ...entry,
      app: store.findById('apps', entry.app_id),
    }))
    .filter((entry) => entry.app);

  res.json({ apps });
});

const saveMyApp = asyncHandler(async (req, res) => {
  const { app_id, version_code, platform = 'android' } = req.body;
  if (!app_id) throw httpError(400, 'app_id is required');

  const app = store.findById('apps', app_id);
  if (!app) throw httpError(404, 'App not found');

  const installedBuild = Number(version_code || app.version_code || 1);
  if (Number.isNaN(installedBuild)) {
    throw httpError(400, 'version_code must be a number');
  }

  const existing = store.findOne(
    'user_apps',
    (item) => item.user_id === req.user.id && item.app_id === app.id,
  );

  const payload = {
    user_id: req.user.id,
    app_id: app.id,
    platform,
    installed_version_name: app.version_name,
    installed_version_code: installedBuild,
    status: 'installed',
    installed_at: existing?.installed_at || new Date().toISOString(),
    last_opened_at: null,
  };

  const userApp = existing
    ? await store.update('user_apps', existing.id, payload)
    : await store.create('user_apps', payload);

  res.status(existing ? 200 : 201).json({ user_app: userApp });
});

const openMyApp = asyncHandler(async (req, res) => {
  const existing = store.findOne(
    'user_apps',
    (item) => item.user_id === req.user.id && item.app_id === req.params.appId,
  );
  if (!existing) throw httpError(404, 'Installed app not found');

  const userApp = await store.update('user_apps', existing.id, {
    last_opened_at: new Date().toISOString(),
  });

  res.json({ user_app: userApp });
});

const uninstallMyApp = asyncHandler(async (req, res) => {
  const deleted = await store.removeWhere(
    'user_apps',
    (item) => item.user_id === req.user.id && item.app_id === req.params.appId,
  );

  res.json({ deleted_count: deleted.length });
});

module.exports = {
  listMyApps,
  saveMyApp,
  openMyApp,
  uninstallMyApp,
};
