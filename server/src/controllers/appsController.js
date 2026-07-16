const store = require('../services/store');
const asyncHandler = require('../utils/asyncHandler');
const { httpError } = require('../utils/httpError');

const listApps = asyncHandler(async (req, res) => {
  const { platform, category_id, type, active = 'true' } = req.query;
  const categories = store.all('categories');

  const apps = store
    .all('apps')
    .filter((app) => !platform || app.platform === platform)
    .filter((app) => !category_id || app.category_id === category_id)
    .filter((app) => active !== 'true' || app.is_active)
    .filter((app) => {
      if (!type) return true;
      const category = categories.find((item) => item.id === app.category_id);
      return category?.type === type;
    })
    .map(withRelations);

  res.json({ apps });
});

const getApp = asyncHandler(async (req, res) => {
  const app = store.findById('apps', req.params.id);
  if (!app) throw httpError(404, 'App not found');
  res.json({ app: withRelations(app) });
});

const createApp = asyncHandler(async (req, res) => {
  const payload = normalizeAppPayload(req.body);
  const screenshotUrls = takeScreenshotUrls(payload);
  const categoryId = payload.category_id || defaultCategoryId('apps');
  validateCategorySelection(categoryId, payload.subcategory_id);
  const app = await store.create('apps', {
    ...payload,
    category_id: categoryId,
    is_active: payload.is_active ?? true,
    is_force_update: payload.is_force_update ?? false,
    updated_at: new Date().toISOString(),
  });
  await replaceScreenshots(app.id, screenshotUrls);
  res.status(201).json({ app: withRelations(app) });
});

const updateApp = asyncHandler(async (req, res) => {
  const payload = normalizeAppPayload(req.body, true);
  const screenshotUrls = takeScreenshotUrls(payload);
  const existing = store.findById('apps', req.params.id);
  if (!existing) throw httpError(404, 'App not found');
  validateCategorySelection(
    payload.category_id ?? existing.category_id,
    payload.subcategory_id,
  );
  if (payload.category_id && payload.subcategory_id === undefined) {
    payload.subcategory_id = null;
  }
  const app = await store.update('apps', req.params.id, payload);
  if (screenshotUrls !== null) await replaceScreenshots(app.id, screenshotUrls);
  res.json({ app: withRelations(app) });
});

const deleteApp = asyncHandler(async (req, res) => {
  const deleted = await store.remove('apps', req.params.id);
  await Promise.all([
    store.removeWhere('app_screenshots', (item) => item.app_id === req.params.id),
    store.removeWhere('downloads', (item) => item.app_id === req.params.id),
    store.removeWhere('user_apps', (item) => item.app_id === req.params.id),
    store.removeWhere('reviews', (item) => item.app_id === req.params.id),
    store.removeWhere('app_updates', (item) => item.app_id === req.params.id),
  ]);
  res.json({ deleted });
});

const createUpdate = asyncHandler(async (req, res) => {
  const app = store.findById('apps', req.params.id);
  if (!app) throw httpError(404, 'App not found');

  const versionCode = Number(req.body.version_code);
  if (!req.body.version_name || Number.isNaN(versionCode)) {
    throw httpError(400, 'version_name and version_code are required');
  }
  if (versionCode <= Number(app.version_code || 0)) {
    throw httpError(400, 'version_code must be greater than current app version_code');
  }

  const fileUrl = req.body.file_url || req.body.apk_file_url || null;
  if (!fileUrl) {
    throw httpError(400, 'file_url is required for app updates');
  }

  await ensureVersionSnapshot(app);

  const update = await store.create('app_updates', {
    app_id: app.id,
    version_name: req.body.version_name,
    version_code: versionCode,
    file_url: fileUrl,
    is_force_update: parseBoolean(req.body.is_force_update),
    changelog: req.body.changelog || '',
  });

  await store.update('apps', app.id, {
    version_name: update.version_name,
    version_code: update.version_code,
    file_url: update.file_url,
    apk_file_url: update.file_url,
    is_force_update: update.is_force_update,
  });

  res.status(201).json({ update });
});

const listUpdates = asyncHandler(async (req, res) => {
  const app = store.findById('apps', req.params.id);
  if (!app) throw httpError(404, 'App not found');

  res.json({ updates: versionHistory(app) });
});

const getAnalytics = asyncHandler(async (_req, res) => {
  const apps = store.all('apps');
  const downloads = store.all('downloads');
  const reviews = store.all('reviews');
  const installs = store.all('user_apps');

  const appStats = apps.map((app) => {
    const appDownloads = downloads.filter((item) => item.app_id === app.id);
    const appReviews = reviews.filter((item) => item.app_id === app.id);
    const appInstalls = installs.filter((item) => item.app_id === app.id);
    const rating = appReviews.length
      ? appReviews.reduce((sum, item) => sum + item.rating, 0) / appReviews.length
      : null;

    return {
      app_id: app.id,
      name: app.name,
      package_name: app.package_name,
      platform: app.platform,
      downloads_count: appDownloads.length,
      installs_count: appInstalls.length,
      reviews_count: appReviews.length,
      rating,
      latest_downloaded_at: appDownloads
        .map((item) => item.downloaded_at)
        .sort()
        .reverse()[0] || null,
    };
  });

  res.json({
    summary: {
      apps_count: apps.length,
      active_apps_count: apps.filter((app) => app.is_active).length,
      downloads_count: downloads.length,
      installs_count: installs.length,
      reviews_count: reviews.length,
      users_count: store.all('users').length,
    },
    apps: appStats.sort((a, b) => b.downloads_count - a.downloads_count),
  });
});

const checkUpdate = asyncHandler(async (req, res) => {
  const app = store.findById('apps', req.params.id);
  if (!app) throw httpError(404, 'App not found');

  res.json(updatePayload(app, Number(req.query.currentBuild || 0)));
});

const checkPackageUpdate = asyncHandler(async (req, res) => {
  const platform = req.query.platform || 'android';
  const app = store.findOne(
    'apps',
    (item) =>
      item.package_name === req.params.packageName && item.platform === platform,
  );
  if (!app) throw httpError(404, 'App not found');

  res.json(updatePayload(app, Number(req.query.currentBuild || 0)));
});

function updatePayload(app, currentBuild) {
  const update = store
    .all('app_updates')
    .filter((item) => item.app_id === app.id)
    .filter((item) => item.version_code > currentBuild)
    .sort((a, b) => b.version_code - a.version_code)[0];

  return {
    update_available: Boolean(update),
    force_update: Boolean(update?.is_force_update),
    latest: update || {
      version_name: app.version_name,
      version_code: app.version_code,
      file_url: app.file_url || app.apk_file_url,
    },
  };
}

async function ensureVersionSnapshot(app) {
  const fileUrl = app.file_url || app.apk_file_url || null;
  if (!fileUrl) return;

  const exists = store
    .all('app_updates')
    .some(
      (item) =>
        item.app_id === app.id && Number(item.version_code) === Number(app.version_code),
    );
  if (exists) return;

  await store.create('app_updates', {
    app_id: app.id,
    version_name: app.version_name,
    version_code: app.version_code,
    file_url: fileUrl,
    is_force_update: false,
    changelog: 'Previous release',
  });
}

function versionHistory(app) {
  const byVersion = new Map();
  const currentFileUrl = app.file_url || app.apk_file_url || null;

  if (currentFileUrl) {
    byVersion.set(Number(app.version_code), {
      app_id: app.id,
      version_name: app.version_name,
      version_code: app.version_code,
      file_url: currentFileUrl,
      is_force_update: Boolean(app.is_force_update),
      changelog: 'Current release',
      current: true,
      created_at: app.updated_at || app.created_at,
    });
  }

  for (const update of store.all('app_updates').filter((item) => item.app_id === app.id)) {
    const versionCode = Number(update.version_code);
    const existing = byVersion.get(versionCode);
    if (existing?.current) continue;
    byVersion.set(versionCode, {
      ...update,
      current: false,
    });
  }

  return [...byVersion.values()].sort(
    (a, b) => Number(b.version_code) - Number(a.version_code),
  );
}

function normalizeAppPayload(body, partial = false) {
  const required = ['name', 'description', 'package_name', 'version_name', 'version_code', 'platform'];
  if (!partial) {
    for (const key of required) {
      if (body[key] === undefined || body[key] === '') {
        throw httpError(400, `${key} is required`);
      }
    }
  }

  const payload = { ...body };
  if (payload.version_code !== undefined) payload.version_code = Number(payload.version_code);
  if (Number.isNaN(payload.version_code)) throw httpError(400, 'version_code must be a number');
  if (payload.is_active !== undefined) payload.is_active = parseBoolean(payload.is_active);
  if (payload.is_force_update !== undefined) {
    payload.is_force_update = parseBoolean(payload.is_force_update);
  }
  return payload;
}

function takeScreenshotUrls(payload) {
  const incoming = payload.screenshot_urls ?? payload.screenshots;
  delete payload.screenshot_urls;
  delete payload.screenshots;

  if (incoming === undefined) return null;
  if (Array.isArray(incoming)) {
    return incoming.map((item) => String(item).trim()).filter(Boolean);
  }
  if (typeof incoming === 'string') {
    return incoming
      .split(/\r?\n|,/)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
}

async function replaceScreenshots(appId, urls) {
  if (urls === null) return;
  await store.removeWhere('app_screenshots', (item) => item.app_id === appId);
  for (const image_url of urls) {
    await store.create('app_screenshots', {
      app_id: appId,
      image_url,
    });
  }
}

function defaultCategoryId(type) {
  return store.all('categories').find((item) => item.type === type)?.id;
}

function validateCategorySelection(categoryId, subcategoryId) {
  if (!categoryId || !store.findById('categories', categoryId)) {
    throw httpError(400, 'Valid category_id is required');
  }
  if (!subcategoryId) return;

  const subcategory = store.findById('subcategories', subcategoryId);
  if (!subcategory || subcategory.category_id !== categoryId) {
    throw httpError(400, 'subcategory_id must belong to selected category_id');
  }
}

function parseBoolean(value) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    return ['true', '1', 'yes', 'on'].includes(value.toLowerCase());
  }
  return false;
}

function withRelations(app) {
  const category = store.findById('categories', app.category_id);
  const subcategory = app.subcategory_id
    ? store.findById('subcategories', app.subcategory_id)
    : null;
  const screenshots = store
    .all('app_screenshots')
    .filter((item) => item.app_id === app.id);
  const reviews = store.all('reviews').filter((item) => item.app_id === app.id);
  const downloads = store
    .all('downloads')
    .filter((item) => item.app_id === app.id);
  const installs = store
    .all('user_apps')
    .filter((item) => item.app_id === app.id);
  const averageRating = reviews.length
    ? reviews.reduce((sum, item) => sum + item.rating, 0) / reviews.length
    : null;

  return {
    ...app,
    category,
    subcategory,
    screenshots,
    rating: averageRating,
    review_count: reviews.length,
    downloads_count: downloads.length,
    installs_count: installs.length,
  };
}

module.exports = {
  listApps,
  getApp,
  createApp,
  updateApp,
  deleteApp,
  createUpdate,
  listUpdates,
  checkUpdate,
  checkPackageUpdate,
  getAnalytics,
};
