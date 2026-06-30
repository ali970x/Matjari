const express = require('express');
const libraryController = require('../controllers/libraryController');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.get('/me', requireAuth, libraryController.listMyApps);
router.post('/me', requireAuth, libraryController.saveMyApp);
router.post('/me/:appId/open', requireAuth, libraryController.openMyApp);
router.delete('/me/:appId', requireAuth, libraryController.uninstallMyApp);

module.exports = router;
