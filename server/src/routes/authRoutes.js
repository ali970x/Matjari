const express = require('express');
const authController = require('../controllers/authController');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/google-login', authController.googleLogin);
router.post('/admin-login', authController.adminLogin);
router.get('/me', requireAuth, authController.me);
router.patch('/me', requireAuth, authController.updateMe);

module.exports = router;
