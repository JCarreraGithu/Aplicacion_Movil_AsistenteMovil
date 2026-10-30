
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,

    // Activar SSL solamente cuando se configure.
    ssl: process.env.DB_SSL === 'true'
        ? { rejectUnauthorized: true }
        : false
});

module.exports = pool;
