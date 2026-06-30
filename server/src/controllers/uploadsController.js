const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const multer = require('multer');
const env = require('../config/env');
const { httpError } = require('../utils/httpError');

const fileSizeLimit = 250 * 1024 * 1024;

function uploader(folderName) {
  if (usesSupabaseUploads()) {
    return multer({
      storage: multer.memoryStorage(),
      limits: { fileSize: fileSizeLimit },
    });
  }

  const destination = path.join(env.uploadsDir, folderName);
  fs.mkdirSync(destination, { recursive: true });

  return multer({
    storage: multer.diskStorage({
      destination: (_req, _file, cb) => cb(null, destination),
      filename: (_req, file, cb) => {
        const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '-');
        cb(null, `${Date.now()}-${safeName}`);
      },
    }),
    limits: { fileSize: fileSizeLimit },
  });
}

function uploadResponse(folderName) {
  return async (req, res, next) => {
    if (!req.file && !req.files) return next(httpError(400, 'No file uploaded'));

    try {
      const files = req.files || [req.file];
      const payload = await Promise.all(
        files.map((file) =>
          usesSupabaseUploads()
            ? supabaseUploadPayload(folderName, file)
            : localUploadPayload(req, folderName, file),
        ),
      );

      return res.status(201).json({
        files: payload,
        file: payload[0] || null,
      });
    } catch (error) {
      return next(error);
    }
  };
}

function localUploadPayload(req, folderName, file) {
  return {
    original_name: file.originalname,
    filename: file.filename,
    size: file.size,
    url: `${requestBaseUrl(req)}/uploads/${folderName}/${file.filename}`,
  };
}

async function supabaseUploadPayload(folderName, file) {
  assertSupabaseUploadConfig();

  const originalName = file.originalname || 'upload.bin';
  const filename = `${Date.now()}-${randomUUID()}-${safeFileName(originalName)}`;
  const objectPath = [env.supabaseStoragePrefix, folderName, filename]
    .filter(Boolean)
    .join('/');
  const encodedPath = encodeObjectPath(objectPath);
  const bucket = encodeURIComponent(env.supabaseStorageBucket);
  const baseUrl = env.supabaseUrl.replace(/\/+$/, '');

  const response = await fetch(`${baseUrl}/storage/v1/object/${bucket}/${encodedPath}`, {
    method: 'POST',
    headers: {
      apikey: env.supabaseServiceRoleKey,
      Authorization: `Bearer ${env.supabaseServiceRoleKey}`,
      'Content-Type': file.mimetype || 'application/octet-stream',
      'x-upsert': 'false',
    },
    body: file.buffer,
  });

  if (!response.ok) {
    const body = await response.text();
    throw httpError(
      502,
      `Supabase upload failed (${response.status}): ${body || response.statusText}`,
    );
  }

  return {
    original_name: originalName,
    filename,
    size: file.size,
    path: objectPath,
    url: `${baseUrl}/storage/v1/object/public/${bucket}/${encodedPath}`,
  };
}

function usesSupabaseUploads() {
  return env.uploadBackend === 'supabase';
}

function assertSupabaseUploadConfig() {
  if (!env.supabaseUrl || !env.supabaseServiceRoleKey || !env.supabaseStorageBucket) {
    throw httpError(
      500,
      'UPLOAD_BACKEND=supabase requires SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and SUPABASE_STORAGE_BUCKET',
    );
  }
  if (typeof fetch !== 'function') {
    throw httpError(500, 'UPLOAD_BACKEND=supabase requires Node.js 18+ fetch support');
  }
}

function requestBaseUrl(req) {
  if (env.publicBaseUrl) return env.publicBaseUrl.replace(/\/+$/, '');

  const proto = firstHeader(req.get('x-forwarded-proto')) || req.protocol || 'http';
  const host = firstHeader(req.get('x-forwarded-host')) || req.get('host');
  return `${proto}://${host}`;
}

function firstHeader(value) {
  return value ? String(value).split(',')[0].trim() : '';
}

function safeFileName(value) {
  return value.replace(/[^a-zA-Z0-9._-]/g, '-');
}

function encodeObjectPath(value) {
  return value.split('/').map(encodeURIComponent).join('/');
}

module.exports = { uploader, uploadResponse };
