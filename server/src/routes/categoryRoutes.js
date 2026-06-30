const express = require('express');
const categoriesController = require('../controllers/categoriesController');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.get('/categories', categoriesController.listCategories);
router.post('/categories', requireAuth, requireAdmin, categoriesController.createCategory);
router.get('/subcategories/:categoryId', categoriesController.listSubcategories);
router.post('/subcategories', requireAuth, requireAdmin, categoriesController.createSubcategory);

module.exports = router;
