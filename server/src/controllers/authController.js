const bcrypt = require('bcryptjs');
const store = require('../services/store');
const asyncHandler = require('../utils/asyncHandler');
const { httpError } = require('../utils/httpError');
const { signToken } = require('../utils/tokens');
const env = require('../config/env');

const register = asyncHandler(async (req, res) => {
  const { email, password, full_name, username, phone_number, avatar_url } = req.body;
  if (!email || !password || !full_name || !phone_number) {
    throw httpError(400, 'email, password, full_name, and phone_number are required');
  }

  const normalizedEmail = String(email).toLowerCase().trim();
  const normalizedUsername = normalizeUsername(username || normalizedEmail.split('@')[0]);
  const normalizedPhone = normalizePhone(phone_number);
  const existing = store.findOne(
    'users',
    (user) =>
      user.email === normalizedEmail ||
      normalizeUsername(user.username) === normalizedUsername ||
      normalizePhone(user.phone_number) === normalizedPhone,
  );
  if (existing) throw httpError(409, 'Email, username, or phone number is already registered');

  const user = await store.create('users', {
    email: normalizedEmail,
    username: normalizedUsername,
    full_name: String(full_name).trim(),
    phone_number: normalizedPhone,
    avatar_url: String(avatar_url || '').trim(),
    password_hash: await bcrypt.hash(password, 10),
    role: 'user',
    blocked: false,
  });

  res.status(201).json({ user: publicUser(user), token: signToken(user) });
});

const login = asyncHandler(async (req, res) => {
  const { email, identifier, password } = req.body;
  const loginId = String(identifier || email || '').toLowerCase().trim();
  if (!loginId || !password) throw httpError(400, 'identifier and password are required');

  const user = store.findOne(
    'users',
    (item) =>
      item.email === loginId ||
      normalizeUsername(item.username) === normalizeUsername(loginId),
  );
  await assertPassword(user, password);

  res.json({ user: publicUser(user), token: signToken(user) });
});

const adminLogin = asyncHandler(async (req, res) => {
  const { username = env.adminUsername, password } = req.body;
  if (!password) throw httpError(400, 'password is required');

  const admin = store.findOne(
    'users',
    (user) => user.role === 'admin' && user.username === username,
  );
  await assertPassword(admin, password);

  res.json({ user: publicUser(admin), token: signToken(admin) });
});

const me = asyncHandler(async (req, res) => {
  res.json({ user: publicUser(req.user) });
});

const updateMe = asyncHandler(async (req, res) => {
  const attrs = {};
  if (req.body.full_name !== undefined) attrs.full_name = String(req.body.full_name).trim();
  if (req.body.avatar_url !== undefined) attrs.avatar_url = String(req.body.avatar_url).trim();
  if (Object.keys(attrs).length === 0) {
    throw httpError(400, 'Nothing to update');
  }

  const user = await store.update('users', req.user.id, attrs);
  res.json({ user: publicUser(user) });
});

const googleLogin = asyncHandler(async (req, res) => {
  const { email, full_name, username, phone_number, avatar_url } = req.body;
  if (!email) throw httpError(400, 'email is required');

  const normalizedEmail = String(email).toLowerCase().trim();
  let user = store.findOne('users', (item) => item.email === normalizedEmail);
  if (!user) {
    if (!phone_number || !full_name) {
      return res.status(202).json({
        needs_registration: true,
        profile: {
          email: normalizedEmail,
          full_name: full_name || normalizedEmail.split('@')[0],
          avatar_url: avatar_url || '',
        },
      });
    }
    user = await store.create('users', {
      email: normalizedEmail,
      username: normalizeUsername(username || normalizedEmail.split('@')[0]),
      full_name: String(full_name).trim(),
      phone_number: normalizePhone(phone_number),
      avatar_url: String(avatar_url || '').trim(),
      password_hash: await bcrypt.hash(randomGooglePassword(normalizedEmail), 10),
      role: 'user',
      blocked: false,
      auth_provider: 'google',
    });
  }

  res.json({ user: publicUser(user), token: signToken(user) });
});

async function assertPassword(user, password) {
  if (!user) throw httpError(401, 'Invalid credentials');
  if (user.blocked === true || user.is_blocked === true) {
    throw httpError(403, 'This account is blocked');
  }
  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) throw httpError(401, 'Invalid credentials');
}

function publicUser(user) {
  const { password_hash: _passwordHash, ...safeUser } = user;
  return safeUser;
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

function randomGooglePassword(email) {
  return `google:${email}:matjari`;
}

module.exports = { register, login, googleLogin, adminLogin, me, updateMe, publicUser };
