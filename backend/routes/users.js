// routes/users.js
const express = require("express");
const { Op } = require("sequelize");
const { User } = require("../models/User");

const router = express.Router();

// Create
router.post("/", async (req, res) => {
  try {
    const { name, email, role } = req.body;
    if (!name || !email) {
      return res.status(400).json({ message: "name and email are required" });
    }
    const user = await User.create({ name, email, role: role || "user" });
    return res.status(201).json(user);
  } catch (e) {
    return res.status(400).json({ message: e.message });
  }
});

// Read (list + simple search + pagination)
router.get("/", async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page ?? "1", 10), 1);
    const pageSize = Math.min(
      Math.max(parseInt(req.query.pageSize ?? "20", 10), 1),
      100
    );
    const q = (req.query.q ?? "").trim();
    const limit = pageSize;
    const offset = (page - 1) * limit;

    const where = q
      ? {
          [Op.or]: [
            { name: { [Op.like]: `%${q}%` } },
            { email: { [Op.like]: `%${q}%` } },
            { role: { [Op.like]: `%${q}%` } },
          ],
        }
      : {};

    const { rows, count } = await User.findAndCountAll({
      where,
      limit,
      offset,
      order: [["createdAt", "DESC"]],
    });

    return res.json({ data: rows, total: count, page, pageSize: limit });
  } catch (e) {
    return res.status(500).json({ message: e.message });
  }
});

// Read (by id)
router.get("/:id", async (req, res) => {
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) return res.status(404).json({ message: "Not found" });
    return res.json(user);
  } catch (e) {
    return res.status(500).json({ message: e.message });
  }
});

// Update
router.put("/:id", async (req, res) => {
  try {
    const { name, email, role } = req.body;
    const user = await User.findByPk(req.params.id);
    if (!user) return res.status(404).json({ message: "Not found" });

    await user.update({ name, email, role });
    return res.json(user);
  } catch (e) {
    return res.status(400).json({ message: e.message });
  }
});

// Delete
router.delete("/:id", async (req, res) => {
  try {
    const deleted = await User.destroy({ where: { id: req.params.id } });
    if (!deleted) return res.status(404).json({ message: "Not found" });
    return res.status(204).send();
  } catch (e) {
    return res.status(500).json({ message: e.message });
  }
});

module.exports = router;
