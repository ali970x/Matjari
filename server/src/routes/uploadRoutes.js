const express = require('express');
const { uploader, uploadResponse } = require('../controllers/uploadsController');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.post(
  '/app-file',
  requireAuth,
  requireAdmin,
  uploader('app-files').single('file'),
  uploadResponse('app-files'),
);

router.post(
  '/icon',
  requireAuth,
  requireAdmin,
  uploader('icons').single('icon'),
  uploadResponse('icons'),
);

router.post(
  '/screenshots',
  requireAuth,
  requireAdmin,
  uploader('screenshots').array('screenshots', 12),
  uploadResponse('screenshots'),
);

module.exports = router;
