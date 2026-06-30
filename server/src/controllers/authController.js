const bcrypt = require('bcryptjs');
const store = require('../services/store');
const asyncHandler = require('../utils/asyncHandler');
const { httpError } = require('../utils/httpError');
const { signToken } = require('../utils/tokens');
const env = require('../config/env');

const register = asyncHandler(async (req, res) => {
  const { email, password, full_name } = req.body;
  if (!email || !password || !full_name) {
    throw httpError(400, 'email, password, and full_name are required');
  }

  const normalizedEmail = String(email).toLowerCase().trim();
  const existing = store.findOne('users', (user) => user.email === normalizedEmail);
  if (existing) throw httpError(409, 'Email is already registered');

  const user = await store.create('users', {
    email: normalizedEmail,
    full_name: String(full_name).trim(),
    password_hash: await bcrypt.hash(password, 10),
    role: 'user',
  });

  res.status(201).json({ user: publicUser(user), token: signToken(user) });
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) throw httpError(400, 'email and password are required');

  const user = store.findOne(
    'users',
    (item) => item.email === String(email).toLowerCase().trim(),
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

async function assertPassword(user, password) {
  if (!user) throw httpError(401, 'Invalid credentials');
  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) throw httpError(401, 'Invalid credentials');
}

function publicUser(user) {
  const { password_hash: _passwordHash, ...safeUser } = user;
  return safeUser;
}

module.exports = { register, login, adminLogin, me, publicUser };
