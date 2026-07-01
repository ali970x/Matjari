const bcrypt = require('bcryptjs');
const store = require('../services/store');
const asyncHandler = require('../utils/asyncHandler');
const { httpError } = require('../utils/httpError');

const listUsers = asyncHandler(async (_req, res) => {
  const users = store
    .all('users')
    .map(publicUser)
    .sort((a, b) => String(a.created_at || '').localeCompare(String(b.created_at || '')));
  res.json({ users });
});

const updateUser = asyncHandler(async (req, res) => {
  const user = store.findById('users', req.params.id);
  if (!user) throw httpError(404, 'User not found');

  const attrs = {};
  if (req.body.email !== undefined) attrs.email = String(req.body.email).toLowerCase().trim();
  if (req.body.username !== undefined) attrs.username = normalizeUsername(req.body.username);
  if (req.body.full_name !== undefined) attrs.full_name = String(req.body.full_name).trim();
  if (req.body.phone_number !== undefined) attrs.phone_number = normalizePhone(req.body.phone_number);
  if (req.body.blocked !== undefined) attrs.blocked = parseBoolean(req.body.blocked);
  if (req.body.password) attrs.password_hash = await bcrypt.hash(String(req.body.password), 10);

  assertUniqueUser(attrs, user.id);

  const updated = await store.update('users', user.id, attrs);
  res.json({ user: publicUser(updated) });
});

const deleteUser = asyncHandler(async (req, res) => {
  const user = store.findById('users', req.params.id);
  if (!user) throw httpError(404, 'User not found');
  if (user.role === 'admin' && adminCount() <= 1) {
    throw httpError(400, 'Cannot delete the last admin');
  }

  const deleted = await store.remove('users', user.id);
  await Promise.all([
    store.removeWhere('user_apps', (item) => item.user_id === user.id),
    store.removeWhere('downloads', (item) => item.user_id === user.id),
    store.removeWhere('reviews', (item) => item.user_id === user.id),
  ]);
  res.json({ deleted: publicUser(deleted) });
});

const updateRole = asyncHandler(async (req, res) => {
  const user = store.findById('users', req.params.id);
  if (!user) throw httpError(404, 'User not found');

  const role = String(req.body.role || '').trim() === 'admin' ? 'admin' : 'user';
  if (user.role === 'admin' && role !== 'admin' && adminCount() <= 1) {
    throw httpError(400, 'Cannot remove the last admin');
  }

  const updated = await store.update('users', user.id, { role });
  res.json({ user: publicUser(updated) });
});

function assertUniqueUser(attrs, currentId) {
  const email = attrs.email;
  const username = attrs.username;
  const phone = attrs.phone_number;
  const existing = store.findOne('users', (user) => {
    if (user.id === currentId) return false;
    return (
      (email && user.email === email) ||
      (username && normalizeUsername(user.username) === username) ||
      (phone && normalizePhone(user.phone_number) === phone)
    );
  });
  if (existing) throw httpError(409, 'Email, username, or phone number is already registered');
}

function publicUser(user) {
  const { password_hash: _passwordHash, ...safeUser } = user;
  return safeUser;
}

function adminCount() {
  return store.all('users').filter((user) => user.role === 'admin').length;
}

function normalizeUsername(value = '') {
  return String(value).toLowerCase().trim().replace(/[^a-z0-9._-]/g, '');
}

function normalizePhone(value = '') {
  const text = String(value).trim();
  if (text.startsWith('+')) return `+${text.replace(/[^0-9]/g, '')}`;
  const digits = text.replace(/[^0-9]/g, '');
  if (digits.startsWith('961')) return `+${digits}`;
  return digits ? `+961${digits.replace(/^0+/, '')}` : '';
}

function parseBoolean(value) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') return ['true', '1', 'yes', 'on'].includes(value.toLowerCase());
  return false;
}

module.exports = { listUsers, updateUser, deleteUser, updateRole };
