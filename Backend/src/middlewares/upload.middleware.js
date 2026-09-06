const multer = require('multer');

const storage = multer.memoryStorage();

const upload = multer({
    storage: storage,

    limits: {
        fileSize: 10 * 1024 * 1024
    },

    fileFilter: (req, file, cb) => {

        const extensionesPermitidas = [
            '.jpg',
            '.jpeg',
            '.png',
            '.webp'
        ];

        const extension = file.originalname
            .toLowerCase()
            .substring(
                file.originalname.lastIndexOf('.')
            );

        if (
            file.mimetype.startsWith('image/') ||
            extensionesPermitidas.includes(extension)
        ) {
            cb(null, true);
        } else {
            cb(
                new Error(
                    'El archivo debe ser una imagen'
                )
            );
        }
    }
});

module.exports = upload;