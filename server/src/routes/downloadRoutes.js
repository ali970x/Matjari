const express = require('express');
const downloadsController = require('../controllers/downloadsController');
const { requireAuth, requireAdmin, requireSelfOrAdmin } = require('../middleware/auth');

const router = express.Router();

router.post('/', requireAuth, downloadsController.createDownload);
router.get('/app/:appId', requireAuth, requireAdmin, downloadsController.getAppDownloads);
router.get(
  '/user/:userId',
  requireAuth,
  requireSelfOrAdmin('userId'),
  downloadsController.getUserDownloads,
);

module.exports = router;
