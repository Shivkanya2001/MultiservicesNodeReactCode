// db.js (CommonJS)
const { Sequelize } = require("sequelize");

const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DB_USER,
  process.env.DB_PASS,
  {
    host: process.env.DB_HOST || "127.0.0.1",
    port: process.env.DB_PORT ? Number(process.env.DB_PORT) : 3306,
    dialect: "mysql",
    logging: false,
  }
);

async function initDb() {
  try {
    await sequelize.authenticate();
    console.log(" DB connection established.");
  } catch (err) {
    console.error("DB connection failed:", err.message);
    process.exit(1);
  }
}

module.exports = { sequelize, initDb };
