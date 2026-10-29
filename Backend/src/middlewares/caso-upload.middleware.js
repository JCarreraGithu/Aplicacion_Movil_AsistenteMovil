const fs = require('fs');
const path = require('path');
const multer = require('multer');

const uploadDirectory = path.join(__dirname, '..', 'uploads', 'casos');

const storage = multer.diskStorage({
    destination: (_req, _file, callback) => {
        fs.mkdir(uploadDirectory, { recursive: true }, (error) => {
            callback(error, uploadDirectory);
        });
    },
    filename: (_req, file, callback) => {
        const extensions = {
            'image/jpeg': '.jpg',
            'image/png': '.png',
            'image/webp': '.webp'
        };
        callback(null, `${Date.now()}-${require('crypto').randomUUID()}${extensions[file.mimetype]}`);
    }
});

module.exports = multer({
    storage,
    limits: { fileSize: 10 * 1024 * 1024, files: 1 },
    fileFilter: (_req, file, callback) => {
        if (['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
            callback(null, true);
        } else {
            callback(new Error('Solo se permiten imágenes JPG, PNG o WEBP'));
        }
    }
});
