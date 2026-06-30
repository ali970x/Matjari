const fs = require('fs/promises');
const path = require('path');
const { randomUUID } = require('crypto');
const bcrypt = require('bcryptjs');
const env = require('../config/env');
const { httpError } = require('../utils/httpError');

const dbFile = path.join(env.dataDir, 'database.json');

let state = emptyState();

function emptyState() {
  return {
    users: [],
    apps: [],
    app_screenshots: [],
    categories: [],
    subcategories: [],
    downloads: [],
    user_apps: [],
    reviews: [],
    app_updates: [],
  };
}

function now() {
  return new Date().toISOString();
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

async function initStore() {
  await fs.mkdir(env.dataDir, { recursive: true });
  await fs.mkdir(env.uploadsDir, { recursive: true });

  try {
    const raw = await fs.readFile(dbFile, 'utf8');
    state = { ...emptyState(), ...JSON.parse(raw) };
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    state = emptyState();
  }

  await seedIfNeeded();
  await save();
}

async function seedIfNeeded() {
  if (!state.users.some((user) => user.role === 'admin')) {
    state.users.push({
      id: randomUUID(),
      email: 'admin@matjari.local',
      username: env.adminUsername,
      full_name: 'Matjari Admin',
      password_hash: await bcrypt.hash(env.adminPassword, 10),
      role: 'admin',
      created_at: now(),
    });
  }

  if (state.categories.length === 0) {
    const apps = category('Apps', 'apps');
    const games = category('Games', 'games');
    const books = category('Books', 'books');
    state.categories.push(apps, games, books);

    state.subcategories.push(
      subcategory(apps.id, 'Shopping'),
      subcategory(apps.id, 'Productivity'),
      subcategory(apps.id, 'Social'),
      subcategory(games.id, 'Action'),
      subcategory(games.id, 'Strategy'),
      subcategory(games.id, 'Simulation'),
      subcategory(books.id, 'Ebooks'),
      subcategory(books.id, 'Audiobooks'),
    );
  }

  const appsCategory = state.categories.find((item) => item.type === 'apps');
  const gamesCategory = state.categories.find((item) => item.type === 'games');
  const booksCategory = state.categories.find((item) => item.type === 'books');
  const shopping = state.subcategories.find((item) => item.name === 'Shopping');
  const productivity = state.subcategories.find((item) => item.name === 'Productivity');
  const social = state.subcategories.find((item) => item.name === 'Social');
  const action = state.subcategories.find((item) => item.name === 'Action');
  const simulation = state.subcategories.find((item) => item.name === 'Simulation');
  const ebooks = state.subcategories.find((item) => item.name === 'Ebooks');

  ensureAppSeed({
    name: 'ChatGPT',
    description: 'Write, learn, plan, and explore ideas with an AI assistant.',
    package_name: 'com.openai.chatgpt',
    platform: 'android',
    category_id: appsCategory.id,
    subcategory_id: productivity.id,
    version_name: '3.2.1',
    version_code: 321,
    size: '156 MB',
    icon_url: '/uploads/seed/chatgpt.png',
  });

  ensureAppSeed({
    name: 'TikTok - Videos, Shop & LIVE',
    description: 'Short videos, creators, shops, and live moments in one place.',
    package_name: 'com.zhiliaoapp.musically',
    platform: 'android',
    category_id: appsCategory.id,
    subcategory_id: social.id,
    version_name: '38.4.0',
    version_code: 3840,
    size: '210 MB',
    icon_url: '/uploads/seed/tiktok.png',
  });

  ensureAppSeed({
    name: 'Alibaba.com - B2B marketplace',
    description: 'Source products, compare suppliers, and manage orders.',
    package_name: 'com.alibaba.intl.android.apps.poseidon',
    platform: 'android',
    category_id: appsCategory.id,
    subcategory_id: shopping.id,
    version_name: '26.21.2',
    version_code: 26212,
    size: '124 MB',
    icon_url: '/uploads/seed/alibaba.png',
  });

  ensureAppSeed({
    name: 'Clash of Clans',
    description: 'Build, battle, and defend your village with your clan.',
    package_name: 'com.supercell.clashofclans',
    platform: 'android',
    category_id: gamesCategory.id,
    subcategory_id: action.id,
    version_name: '18.0.2',
    version_code: 1802,
    size: '316 MB',
    icon_url: '/uploads/seed/clash-of-clans.png',
  });

  ensureAppSeed({
    name: 'War Drone: 3D Shooting Games',
    description: 'Deploy drones and protect troops in fast missions.',
    package_name: 'com.matjari.demo.wardrone',
    platform: 'android',
    category_id: gamesCategory.id,
    subcategory_id: action.id,
    version_name: '7.1.0',
    version_code: 710,
    size: '401 MB',
    icon_url: '/uploads/seed/war-drone.png',
  });

  ensureAppSeed({
    name: 'RFS - Real Flight Simulator',
    description: 'Pilot aircraft and land at airports around the world.',
    package_name: 'it.rortos.realflightsimulator',
    platform: 'android',
    category_id: gamesCategory.id,
    subcategory_id: simulation.id,
    version_name: '2.7.4',
    version_code: 274,
    size: '512 MB',
    icon_url: '/uploads/seed/rfs.png',
  });

  ensureAppSeed({
    name: 'Project Hail Mary: A Novel',
    description: 'A survival story across space, memory, and impossible odds.',
    package_name: 'book.project-hail-mary',
    platform: 'android',
    category_id: booksCategory.id,
    subcategory_id: ebooks.id,
    version_name: 'Book',
    version_code: 1,
    size: 'Ebook',
    icon_url: '/uploads/seed/project-hail-mary.png',
  });
}

function category(name, type) {
  return { id: randomUUID(), name, type, created_at: now() };
}

function subcategory(categoryId, name) {
  return { id: randomUUID(), category_id: categoryId, name, created_at: now() };
}

function appSeed(data) {
  const timestamp = now();
  return {
    id: randomUUID(),
    file_url: null,
    apk_file_url: null,
    is_active: true,
    is_force_update: false,
    created_at: timestamp,
    updated_at: timestamp,
    ...data,
  };
}

function ensureAppSeed(data) {
  const exists = state.apps.some((app) => app.package_name === data.package_name);
  if (!exists) {
    state.apps.push(appSeed(data));
  }
}

async function save() {
  await fs.writeFile(dbFile, JSON.stringify(state, null, 2));
}

function all(collection) {
  assertCollection(collection);
  return clone(state[collection]);
}

function findById(collection, id) {
  assertCollection(collection);
  const item = state[collection].find((record) => record.id === id);
  return item ? clone(item) : null;
}

function findOne(collection, predicate) {
  assertCollection(collection);
  const item = state[collection].find(predicate);
  return item ? clone(item) : null;
}

async function create(collection, attrs) {
  assertCollection(collection);
  const record = {
    id: randomUUID(),
    created_at: now(),
    ...attrs,
  };
  state[collection].push(record);
  await save();
  return clone(record);
}

async function update(collection, id, attrs) {
  assertCollection(collection);
  const index = state[collection].findIndex((record) => record.id === id);
  if (index === -1) throw httpError(404, `${collection} record not found`);

  state[collection][index] = {
    ...state[collection][index],
    ...attrs,
    updated_at: now(),
  };
  await save();
  return clone(state[collection][index]);
}

async function remove(collection, id) {
  assertCollection(collection);
  const index = state[collection].findIndex((record) => record.id === id);
  if (index === -1) throw httpError(404, `${collection} record not found`);
  const [deleted] = state[collection].splice(index, 1);
  await save();
  return clone(deleted);
}

async function removeWhere(collection, predicate) {
  assertCollection(collection);
  const deleted = [];
  state[collection] = state[collection].filter((record) => {
    if (predicate(record)) {
      deleted.push(record);
      return false;
    }
    return true;
  });
  await save();
  return clone(deleted);
}

function assertCollection(collection) {
  if (!Object.prototype.hasOwnProperty.call(state, collection)) {
    throw new Error(`Unknown collection: ${collection}`);
  }
}

module.exports = {
  initStore,
  all,
  findById,
  findOne,
  create,
  update,
  remove,
  removeWhere,
};
