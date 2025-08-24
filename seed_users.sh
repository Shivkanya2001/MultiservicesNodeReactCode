#!/usr/bin/env bash
set -euo pipefail
DB_CONTAINER="${DB_CONTAINER:-mysql_db}"
DB_USER="${MYSQL_USER:-root}"
DB_PASS="${MYSQL_PASSWORD:-root}"

echo "[SEED] Inserting sample user into usersdb.users (if table exists)…"
docker exec -i "$DB_CONTAINER" mysql -u"$DB_USER" -p"$DB_PASS" -e "
USE usersdb;
CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(160) NOT NULL UNIQUE,
  role VARCHAR(40) NOT NULL DEFAULT 'user',
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
);
INSERT INTO users (name,email,role,createdAt,updatedAt)
VALUES ('Admin User','admin@example.com','admin',NOW(),NOW());
SELECT COUNT(*) AS total FROM users;"
