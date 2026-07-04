const express = require('express');
const appsController = require('../controllers/appsController');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.get('/', appsController.listApps);
router.post('/', requireAuth, requireAdmin, appsController.createApp);
router.get('/analytics/overview', requireAuth, requireAdmin, appsController.getAnalytics);
router.get('/package/:packageName/check-update', appsController.checkPackageUpdate);
router.get('/:id/updates', appsController.listUpdates);
router.get('/:id', appsController.getApp);
router.put('/:id', requireAuth, requireAdmin, appsController.updateApp);
router.delete('/:id', requireAuth, requireAdmin, appsController.deleteApp);
router.post('/:id/update', requireAuth, requireAdmin, appsController.createUpdate);
router.get('/:id/check-update', appsController.checkUpdate);

module.exports = router;
