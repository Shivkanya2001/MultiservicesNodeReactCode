// models/User.js
const { DataTypes } = require("sequelize");
const { sequelize } = require("../db");

const User = sequelize.define(
  "User",
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      primaryKey: true,
      autoIncrement: true,
    },
    name: { type: DataTypes.STRING(120), allowNull: false },
    email: {
      type: DataTypes.STRING(160),
      allowNull: false,
      unique: true,
      validate: { isEmail: true },
    },
    role: {
      type: DataTypes.STRING(40),
      allowNull: false,
      defaultValue: "user",
    },
  },
  {
    tableName: "users",
    timestamps: true,
  }
);

module.exports = { User };
