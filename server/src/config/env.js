const path = require('path');
require('dotenv').config();

const rootDir = path.resolve(__dirname, '../..');

module.exports = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 4000),
  jwtSecret: process.env.JWT_SECRET || 'matjari-local-dev-secret',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  adminUsername: process.env.ADMIN_USERNAME || 'admin',
  adminPassword: process.env.ADMIN_PASSWORD || '123456',
  publicBaseUrl: process.env.PUBLIC_BASE_URL || '',
  dataBackend: process.env.DATA_BACKEND || 'json',
  uploadBackend: process.env.UPLOAD_BACKEND || 'local',
  supabaseUrl: process.env.SUPABASE_URL || '',
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
  supabaseStateTable: process.env.SUPABASE_STATE_TABLE || 'matjari_state',
  supabaseStateId: process.env.SUPABASE_STATE_ID || 'default',
  supabaseStorageBucket: process.env.SUPABASE_STORAGE_BUCKET || '',
  supabaseStoragePrefix: process.env.SUPABASE_STORAGE_PREFIX || 'uploads',
  dataDir: path.join(rootDir, 'data'),
  uploadsDir: path.join(rootDir, 'uploads'),
};
