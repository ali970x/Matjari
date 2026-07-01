const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const env = require('./config/env');
const authRoutes = require('./routes/authRoutes');
const appRoutes = require('./routes/appRoutes');
const uploadRoutes = require('./routes/uploadRoutes');
const downloadRoutes = require('./routes/downloadRoutes');
const reviewRoutes = require('./routes/reviewRoutes');
const libraryRoutes = require('./routes/libraryRoutes');
const categoryRoutes = require('./routes/categoryRoutes');
const userRoutes = require('./routes/userRoutes');
const { notFound, errorHandler } = require('./middleware/errorHandler');

const app = express();
const publicDir = path.resolve(__dirname, '../public');

app.set('trust proxy', true);
app.use(cors());
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan(env.nodeEnv === 'production' ? 'combined' : 'dev'));
app.use('/uploads', express.static(path.resolve(env.uploadsDir)));
app.use('/admin-assets', express.static(publicDir));

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    name: 'Matjari API',
    data_backend: env.dataBackend,
    upload_backend: env.uploadBackend,
  });
});

app.get('/admin', (_req, res) => {
  res.sendFile(path.join(publicDir, 'admin.html'));
});

app.use('/api/auth', authRoutes);
app.use('/api/apps', appRoutes);
app.use('/api/uploads', uploadRoutes);
app.use('/api/downloads', downloadRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/library', libraryRoutes);
app.use('/api/users', userRoutes);
app.use('/api', categoryRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
