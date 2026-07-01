const express = require('express');
const usersController = require('../controllers/usersController');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.get('/', requireAuth, requireAdmin, usersController.listUsers);
router.put('/:id', requireAuth, requireAdmin, usersController.updateUser);
router.delete('/:id', requireAuth, requireAdmin, usersController.deleteUser);
router.post('/:id/role', requireAuth, requireAdmin, usersController.updateRole);

module.exports = router;
