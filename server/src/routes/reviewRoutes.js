const express = require('express');
const reviewsController = require('../controllers/reviewsController');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.post('/', requireAuth, reviewsController.createReview);
router.get('/app/:appId', reviewsController.getAppReviews);

module.exports = router;
