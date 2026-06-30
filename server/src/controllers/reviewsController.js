const store = require('../services/store');
const asyncHandler = require('../utils/asyncHandler');
const { httpError } = require('../utils/httpError');

const createReview = asyncHandler(async (req, res) => {
  const { app_id, rating, comment = '' } = req.body;
  const numericRating = Number(rating);
  if (!app_id || Number.isNaN(numericRating)) {
    throw httpError(400, 'app_id and rating are required');
  }
  if (numericRating < 1 || numericRating > 5) {
    throw httpError(400, 'rating must be between 1 and 5');
  }
  if (!store.findById('apps', app_id)) throw httpError(404, 'App not found');

  const review = await store.create('reviews', {
    user_id: req.user.id,
    app_id,
    rating: numericRating,
    comment,
  });

  res.status(201).json({ review });
});

const getAppReviews = asyncHandler(async (req, res) => {
  const reviews = store
    .all('reviews')
    .filter((item) => item.app_id === req.params.appId)
    .map((review) => {
      const user = store.findById('users', review.user_id);
      return {
        ...review,
        user: user
          ? { id: user.id, email: user.email, full_name: user.full_name }
          : null,
      };
    });

  res.json({ reviews });
});

module.exports = { createReview, getAppReviews };
