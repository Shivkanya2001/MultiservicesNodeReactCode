// server.js (CommonJS)
const express = require("express");
const cors = require("cors");
require("dotenv").config();

const { initDb, sequelize } = require("./db");
const usersRouter = require("./routes/users");

const app = express();
app.use(
  cors({
    origin: (process.env.CORS_ORIGIN || "http://localhost:3000").split(","),
  })
);
app.use(express.json());

app.get("/api/health", (_req, res) => res.json({ ok: true }));
app.use("/api/users", usersRouter);

const port = process.env.PORT || 4000;

(async () => {
  await initDb();
  await sequelize.sync({ alter: true }); // dev-only; use migrations for prod
  app.listen(port, "0.0.0.0", () =>
    console.log(`API listening on http://0.0.0.0:${port}`)
  );
})();
