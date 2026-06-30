const { HttpError } = require('../utils/httpError');

function notFound(req, _res, next) {
  next(new HttpError(404, `Route not found: ${req.method} ${req.originalUrl}`));
}

function errorHandler(error, _req, res, _next) {
  const status = error.status || 500;
  const payload = {
    error: {
      message: status === 500 ? 'Internal server error' : error.message,
      status,
    },
  };

  if (error.details) payload.error.details = error.details;
  if (status === 500) console.error(error);

  res.status(status).json(payload);
}

module.exports = { notFound, errorHandler };
