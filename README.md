# Building an Information Security System

# Create a Node.js Project

npm init -y

# Start Localhost Docker

docker-compose up -d
docker-compose down

# Run GLPI (https://github.com/glpi-project/glpi)

Uses the official `glpi/glpi` image plus a MariaDB database.

    cp .env.example .env        # adjust ports / DB credentials if needed
    docker compose up -d

Then open http://localhost:8080 — GLPI auto-installs on first start
(this takes a minute; watch progress with `docker compose logs -f glpi`).

Default GLPI logins after install: glpi/glpi (admin), tech/tech,
normal/normal, post-only/postonly. Change or delete them immediately.

    docker compose down          # stop
    docker compose down -v       # stop and wipe database + files

# Zabbix (https://www.zabbix.com) integrated with GLPI

The same `docker compose up -d` also starts Zabbix 7.4:

| Service         | URL / port                | Notes                                  |
|-----------------|---------------------------|----------------------------------------|
| `zabbix-web`    | http://localhost:8081     | Frontend. Login: `Admin` / `zabbix`    |
| `zabbix-server` | tcp://localhost:10051     | Trapper port for agents / proxies      |
| `zabbix-agent`  | (internal)                | Monitors the stack; reports to server  |

## How it is integrated with GLPI

- **Shared database server.** GLPI and Zabbix run on the *same* `db`
  (MariaDB) container, each with its own database and user. The `zabbix`
  database + user are created on first boot by `db-init/10-zabbix.sql`.
- **Shared network.** All containers sit on the compose default network, so
  GLPI can reach `http://zabbix-web:8080` and the Zabbix API, and Zabbix can
  reach `http://glpi:80` — no host networking needed.
- **Application-level sync** is then configured in the UIs, e.g. the GLPI
  *Monitoring / Zabbix* plugin (Setup > Plugins) using a Zabbix API token
  (Zabbix: Users > API tokens), or Zabbix scripts/webhooks that push events
  into GLPI's REST API (GLPI: Setup > General > API).

## Notes

- The `zabbix` database is only auto-created when the MariaDB data volume is
  empty. If you already ran the stack before adding Zabbix, either
  `docker compose down -v` and start again, or create it manually:

      docker compose exec db mariadb -uroot -p"$DB_ROOT_PASSWORD" \
        -e "CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
            CREATE USER 'zabbix'@'%' IDENTIFIED BY 'zabbix';
            GRANT ALL ON zabbix.* TO 'zabbix'@'%'; FLUSH PRIVILEGES;"

- The Zabbix server imports its schema on first start; the frontend shows a
  DB-connection error for a minute until that finishes.

# Install GLPI Agent on macOS

Download
https://github.com/glpi-project/glpi-agent/releases

Edit
/Applications/GLPI-Agent/etc/agent.cfg

server = http://localhost:8080/front/inventory.php
tag = macOS

Test
sudo /Applications/GLPI-Agent/bin/glpi-agent --debug

# Install Zabbix Agent on macOS

Download
https://cdn.zabbix.com/zabbix/binaries/stable/7.4/7.4.1/zabbix_agent-7.4.1-macos-amd64-openssl.tar.gz?utm_source=chatgpt.com

cd ~/Downloads

mkdir -p ~/Downloads/zabbix

tar -xzf zabbix_agent-7.4.1-macos-amd64-openssl.tar.gz -C ~/Downloads/zabbix

find ~/Downloads/zabbix -maxdepth 3 -type f
find ~/Downloads/zabbix -type f -name "zabbix_agentd" -o -name "zabbix_get"

sudo mkdir -p /usr/local/zabbix
sudo cp -R ~/Downloads/zabbix/* /usr/local/zabbix/
find /usr/local/zabbix -maxdepth 4 -type f
sudo chmod +x /usr/local/zabbix/sbin/zabbix_agentd
/usr/local/zabbix/sbin/zabbix_agentd -V

sudo mkdir -p /usr/local/etc/zabbix/zabbix_agentd.d
sudo cp /usr/local/zabbix/etc/zabbix/zabbix_agentd.conf /usr/local/etc/zabbix/zabbix_agentd.conf

Edit
/usr/local/etc/zabbix/zabbix_agentd.conf

sudo mkdir -p /usr/local/etc/zabbix_agentd.conf.d

/usr/local/zabbix/sbin/zabbix_agentd -c /usr/local/etc/zabbix/zabbix_agentd.conf -t

/usr/local/zabbix/sbin/zabbix_agentd -c /usr/local/etc/zabbix/zabbix_agentd.conf -V

file /usr/local/zabbix/sbin/zabbix_agentd

pkill zabbix_agentd

/usr/local/zabbix/sbin/zabbix_agentd -c /usr/local/etc/zabbix/zabbix_agentd.conf

ps aux | grep '[z]abbix_agentd'

cat /tmp/zabbix_agentd.log

scutil --get LocalHostName
Users-MacBook-Pro