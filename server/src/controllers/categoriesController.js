const store = require('../services/store');
const asyncHandler = require('../utils/asyncHandler');
const { httpError } = require('../utils/httpError');

const listCategories = asyncHandler(async (_req, res) => {
  const subcategories = store.all('subcategories');
  const categories = store.all('categories').map((category) => ({
    ...category,
    subcategories: subcategories.filter((item) => item.category_id === category.id),
  }));
  res.json({ categories });
});

const createCategory = asyncHandler(async (req, res) => {
  const { name, type } = req.body;
  if (!name || !type) throw httpError(400, 'name and type are required');
  const category = await store.create('categories', { name, type });
  res.status(201).json({ category });
});

const listSubcategories = asyncHandler(async (req, res) => {
  const subcategories = store
    .all('subcategories')
    .filter((item) => item.category_id === req.params.categoryId);
  res.json({ subcategories });
});

const createSubcategory = asyncHandler(async (req, res) => {
  const { category_id, name } = req.body;
  if (!category_id || !name) throw httpError(400, 'category_id and name are required');
  if (!store.findById('categories', category_id)) throw httpError(404, 'Category not found');
  const subcategory = await store.create('subcategories', { category_id, name });
  res.status(201).json({ subcategory });
});

module.exports = {
  listCategories,
  createCategory,
  listSubcategories,
  createSubcategory,
};
