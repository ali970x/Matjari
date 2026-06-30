const store = require('../services/store');
const { verifyToken } = require('../utils/tokens');
const { httpError } = require('../utils/httpError');

function requireAuth(req, _res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(httpError(401, 'Missing bearer token'));
  }

  try {
    const payload = verifyToken(token);
    const user = store.findById('users', payload.sub);
    if (!user) return next(httpError(401, 'Invalid token user'));
    req.user = user;
    return next();
  } catch (_error) {
    return next(httpError(401, 'Invalid or expired token'));
  }
}

function requireAdmin(req, _res, next) {
  if (req.user?.role !== 'admin') {
    return next(httpError(403, 'Admin access required'));
  }
  return next();
}

function requireSelfOrAdmin(paramName = 'userId') {
  return (req, _res, next) => {
    if (req.user?.role === 'admin' || req.user?.id === req.params[paramName]) {
      return next();
    }
    return next(httpError(403, 'You can only access your own records'));
  };
}

module.exports = { requireAuth, requireAdmin, requireSelfOrAdmin };
