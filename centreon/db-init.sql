-- Prepares the Centreon container's bundled MariaDB so the web install wizard
-- (http://localhost:8082/centreon) can connect as root.
--
-- Runs once, automatically, on first container start (via db-init.service ->
-- db-init.sh). Same idea as db-init/10-zabbix.sql, but Centreon ships its OWN
-- MariaDB inside this container instead of using the shared `db` service, so it
-- cannot use the mysql image's /docker-entrypoint-initdb.d hook.
--
-- Credentials for the installer's "Database information" step:
--   Database Host Address : localhost
--   Root user / password  : root / root

-- Give the local root account a password (installer refuses an unsecured DBMS).
ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';

-- The web installer connects over TCP, which never matches root@'localhost'
-- (that grant is UNIX-socket only in MariaDB). Add TCP-capable root accounts.
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Basic hardening (mirrors mariadb-secure-installation).
DELETE FROM mysql.user WHERE User = '';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db = 'test' OR Db LIKE 'test\\_%';

FLUSH PRIVILEGES;
