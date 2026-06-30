const store = require('../services/store');
const asyncHandler = require('../utils/asyncHandler');
const { httpError } = require('../utils/httpError');

const createDownload = asyncHandler(async (req, res) => {
  const { app_id, platform = 'android', app_version } = req.body;
  if (!app_id) throw httpError(400, 'app_id is required');
  const app = store.findById('apps', app_id);
  if (!app) throw httpError(404, 'App not found');

  const download = await store.create('downloads', {
    user_id: req.user.id,
    app_id,
    downloaded_at: new Date().toISOString(),
    platform,
    app_version: app_version || app.version_name,
  });

  res.status(201).json({ download });
});

const getAppDownloads = asyncHandler(async (req, res) => {
  const downloads = store
    .all('downloads')
    .filter((item) => item.app_id === req.params.appId)
    .map((download) => ({
      ...download,
      user: stripPassword(store.findById('users', download.user_id)),
    }));

  res.json({ downloads });
});

const getUserDownloads = asyncHandler(async (req, res) => {
  const downloads = store
    .all('downloads')
    .filter((item) => item.user_id === req.params.userId)
    .map((download) => ({
      ...download,
      app: store.findById('apps', download.app_id),
    }));

  res.json({ downloads });
});

function stripPassword(user) {
  if (!user) return null;
  const { password_hash: _passwordHash, ...safeUser } = user;
  return safeUser;
}

module.exports = { createDownload, getAppDownloads, getUserDownloads };
