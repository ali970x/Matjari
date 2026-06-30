const fs = require('fs');
const path = require('path');
const multer = require('multer');
const env = require('../config/env');
const { httpError } = require('../utils/httpError');

function uploader(folderName) {
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
    limits: { fileSize: 250 * 1024 * 1024 },
  });
}

function uploadResponse(folderName) {
  return (req, res, next) => {
    if (!req.file && !req.files) return next(httpError(400, 'No file uploaded'));

    const files = req.files || [req.file];
    const payload = files.map((file) => ({
      original_name: file.originalname,
      filename: file.filename,
      size: file.size,
      url: `${env.publicBaseUrl}/uploads/${folderName}/${file.filename}`,
    }));

    return res.status(201).json({
      files: payload,
      file: payload[0] || null,
    });
  };
}

module.exports = { uploader, uploadResponse };
