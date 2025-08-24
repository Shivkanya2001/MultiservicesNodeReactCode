@echo off
setlocal
set DB_CONTAINER=mysql_db
set DB_USER=%MYSQL_USER%
set DB_PASS=%MYSQL_PASSWORD%
if "%DB_USER%"=="" set DB_USER=root
if "%DB_PASS%"=="" set DB_PASS=root

echo [SEED] Inserting sample user into usersdb.users (if table exists)…
docker exec -i %DB_CONTAINER% mysql -u%DB_USER% -p%DB_PASS% -e "USE usersdb; CREATE TABLE IF NOT EXISTS users (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, name VARCHAR(120) NOT NULL, email VARCHAR(160) NOT NULL UNIQUE, role VARCHAR(40) NOT NULL DEFAULT 'user', createdAt DATETIME NOT NULL, updatedAt DATETIME NOT NULL); INSERT INTO users (name,email,role,createdAt,updatedAt) VALUES ('Admin User','admin@example.com','admin',NOW(),NOW()); SELECT COUNT(*) AS total FROM users;"
endlocal
