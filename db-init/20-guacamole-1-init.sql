-- Creates the Apache Guacamole authentication database + user on the shared
-- MariaDB server, on first boot (before 20-guacamole-2-schema.sql loads the
-- Guacamole tables into it).
--
-- Guacamole's MySQL account only needs DML on its own schema.
-- Values must match the guacamole service env in docker-compose.yml.

CREATE DATABASE IF NOT EXISTS `guacamole_db`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'guacamole'@'%' IDENTIFIED BY 'guacamole';
GRANT SELECT, INSERT, UPDATE, DELETE ON `guacamole_db`.* TO 'guacamole'@'%';

FLUSH PRIVILEGES;
