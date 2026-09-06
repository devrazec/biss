-- Runs once, only when the MariaDB data volume is first initialised.
-- Creates a dedicated database + user for Zabbix on the same DB server GLPI uses.
-- Zabbix requires the utf8mb4_bin collation for its schema.

CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;

CREATE USER IF NOT EXISTS 'zabbix'@'%' IDENTIFIED BY 'zabbix';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%';
FLUSH PRIVILEGES;

-- Note: log_bin_trust_function_creators is enabled via a server flag in
-- docker-compose.yml so the Zabbix schema import can create stored functions.
