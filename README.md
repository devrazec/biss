# Building an Information Security System

# Create a Node.js Project

npm init -y

# Start Localhost Docker

docker-compose up -d
docker-compose down
docker compose down -v

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

# Network Discovery & SNMP Inventory

The Docker stack does not run a GLPI Agent for network scanning — it is done
from a machine that sits on the target network (see *Install GLPI Agent on
macOS* below). A containerised agent on the compose bridge network cannot reach
LAN devices over SNMP / ARP / NetBIOS anyway.

To scan the network for SNMP devices (switches, routers, printers, APs, UPS):

1. Install the **GLPI Inventory** plugin in GLPI (Setup > Plugins) — GLPI core
   inventory does not do SNMP network tasks.
2. Run a GLPI Agent on a host on the target subnet, in managed mode:
   `glpi-agent --server http://<glpi-host>:8080/ --daemon`.
3. In GLPI's *GLPI Inventory* menu, define an IP range + SNMP credentials and a
   NetDiscovery / NetInventory task assigned to that agent.

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

# Centreon (https://www.centreon.com) integrated with GLPI

Centreon 24.10 (LTS) is built from `centreon/Dockerfile` and started by the
same `docker compose up -d`.

| Service    | URL / port                       | Notes                              |
|------------|----------------------------------|------------------------------------|
| `centreon` | http://localhost:8082/centreon   | Web install wizard on first run    |

## Why it looks different from GLPI / Zabbix

Centreon is not shipped as a container image. It runs Apache, php-fpm, MariaDB,
`centengine`, `cbd` (broker), `gorgone` and `centreontrapd` together under
**systemd**. So this service:

- runs `systemd` as PID 1 — it needs `privileged: true` and `cgroup: host`
  (already set in `docker-compose.yml`; works on Docker Desktop and most
  cgroup v2 Linux hosts);
- ships its **own** MariaDB instead of sharing the `db` service (Centreon is
  very specific about MariaDB tuning and local-infile access).

## First-run setup

1. `docker compose up -d` (first build takes a few minutes). On first start the
   `db-init.service` inside the container runs `centreon/db-init.sql` once — it
   sets the MariaDB root password and adds TCP-capable root accounts so the web
   installer can connect (the installer refuses an unsecured DBMS). Check it ran:
   `docker compose exec centreon journalctl -u db-init.service`.
2. Open http://localhost:8082/centreon and run the wizard:
   - Database Host Address: `localhost`
   - Root user: `root` — Root password: `root`
   - Database user name: `centreon` — Database user password: `centreon`
   - Create the Centreon admin account when prompted.
3. After install, check services: `docker compose exec centreon systemctl status centreon`.

## How it is integrated with GLPI

- **Shared compose network.** `centreon` sits on the same network as `glpi`,
  so Centreon can reach `http://glpi:80` (GLPI REST API) and GLPI can reach
  `http://centreon:80/centreon/api/...`.
- **Application-level sync** is configured afterwards: a GLPI ticket/asset
  connector driven by Centreon's *Stream Connector* / event webhooks, or a
  GLPI plugin polling the Centreon REST API with an API token
  (Centreon: Administration > API tokens).

# Guacamole (https://guacamole.apache.org) for remote administration

Apache Guacamole 1.6 is a clientless RDP / VNC / SSH gateway — open a remote
desktop or shell to any GLPI-tracked asset straight from the browser, no client
software. Started by the same `docker compose up -d`.

| Service     | URL / port                        | Notes                              |
|-------------|-----------------------------------|------------------------------------|
| `guacamole` | http://localhost:8083/guacamole/  | Login `guacadmin` / `guacadmin`    |
| `guacd`     | (internal)                        | Protocol proxy daemon              |

**Change the `guacadmin` password immediately** (top-right menu > Settings >
Preferences).

## How it is integrated with GLPI

- **Shared database.** Guacamole stores its connections, users and history in
  the `guacamole_db` database on the *same* `db` MariaDB container GLPI uses
  (created by `db-init/20-guacamole-1-init.sql`; tables loaded by
  `db-init/20-guacamole-2-schema.sql`).
- **Shared network.** `guacamole` / `guacd` reach every other container by name
  (e.g. RDP to a Windows asset, SSH to `centreon`, VNC to a lab VM on the host
  via `host.docker.internal`).
- **Launch from a GLPI asset.** In GLPI create an *external link*
  (Setup > Dropdowns > External links, or Administration > ... > Links) on the
  Computer/Network device item type pointing at a Guacamole connection, e.g.
  `http://localhost:8083/guacamole/#/client/<base64>` where `<base64>` is
  `<connectionID>` + `\0c\0` + `mysql` base64-encoded. The asset's IP/name
  fields (`[IP]`, `[NAME]`) can be substituted into the URL.
- Point Guacamole and GLPI at the same LDAP/SSO later so one login covers both.

## Note

The `guacamole_db` database is only auto-created when the `db_data` volume is
first initialised. If the stack was already running before Guacamole was added,
load it once manually:

    docker compose exec -T db mariadb -uroot -p"$DB_ROOT_PASSWORD" < db-init/20-guacamole-1-init.sql
    docker compose exec -T db mariadb -uroot -p"$DB_ROOT_PASSWORD" < db-init/20-guacamole-2-schema.sql

# RustDesk server (https://rustdesk.com) for remote administration

Self-hosted RustDesk OSS server (v1.1.16) so RustDesk clients connect through
*your* infrastructure instead of the public rendezvous servers. Started by the
same `docker compose up -d`.

| Container       | Ports                                   | Role                            |
|-----------------|-----------------------------------------|---------------------------------|
| `rustdesk-hbbs` | 21115/tcp, 21116/tcp+udp, 21118/tcp     | ID / rendezvous (registration)  |
| `rustdesk-hbbr` | 21117/tcp, 21119/tcp                    | Relay (fallback when no P2P)    |

## Client setup

1. Set `RUSTDESK_RELAY_HOST` in `.env` to this host's LAN/public IP (not
   `127.0.0.1` unless the client is on this machine), then
   `docker compose up -d rustdesk-hbbs`.
2. Get the server public key:

       docker run --rm -v glpi_rustdesk_data:/d alpine cat /d/id_ed25519.pub

3. In the RustDesk client: **Settings > Network > ID/Relay Server**
   - ID Server: `<RUSTDESK_RELAY_HOST>`
   - Relay Server: `<RUSTDESK_RELAY_HOST>` (leave blank to use the ID server)
   - Key: the value from step 2

## How it ties in with GLPI

- The **GLPI Agent** inventories each machine's RustDesk ID into
  GLPI > the computer's **Remote management** tab, so every asset's RustDesk ID
  is visible next to it in the inventory.
- To connect: read the ID from that tab, punch it into a RustDesk client that
  points at this server (above). No public RustDesk servers involved.
- `rustdesk_data` volume holds the key pair and `db_v2.sqlite3` (registered
  peers); back it up if you don't want clients to re-key after a rebuild.

# Wazuh (https://wazuh.com) as the security layer

Wazuh 4.14 single-node stack (SIEM / XDR) — threat detection, file integrity
monitoring, rootkit and vulnerability detection, security configuration
assessment (SCA) and active response for the assets tracked in GLPI. Three
containers, defined in `docker-compose.yml` (and `docker-compose-centreon.yml`):

| Service           | URL / port                     | Notes                                        |
|-------------------|--------------------------------|----------------------------------------------|
| `wazuh.dashboard` | https://localhost:8444         | Web UI. Login `admin` / `SecretPassword`     |
| `wazuh.manager`   | tcp://localhost:1514 (events)  | Agents enroll on `1515`, API on `55000`      |
| `wazuh.indexer`   | (internal)                     | OpenSearch store for alerts / events         |

Config lives under `wazuh/config/` (mounted read-only into the containers);
it is copied from the upstream `wazuh/wazuh-docker` `single-node` deployment.

## First-run setup

1. **Host prerequisite.** The indexer (OpenSearch) needs
   `vm.max_map_count >= 262144`. Docker Desktop sets this already; on a Linux
   host run `sudo sysctl -w vm.max_map_count=262144` (persist it in
   `/etc/sysctl.conf`).

2. **Generate the certificates once**, from the repo root, before the first
   `docker compose up`:

       docker compose -f wazuh/generate-indexer-certs.yml run --rm generator

   This writes the root CA + node certs into
   `wazuh/config/wazuh_indexer_ssl_certs/` (git-ignored).

3. **Start the stack:**

       docker compose up -d

   The indexer takes ~1 minute to come up; until then the dashboard logs
   `Wazuh indexer is not ready yet` and the UI shows a connection error. Then
   open https://localhost:8444 (accept the self-signed certificate warning).

## Default credentials — change them

The stack ships with the upstream demo passwords. To harden it, follow
*Changing the default password of the Wazuh users* in the Wazuh docs: generate
new bcrypt hashes, update `wazuh/config/wazuh_indexer/internal_users.yml`, then
update the matching `INDEXER_PASSWORD` / `DASHBOARD_PASSWORD` / `API_PASSWORD`
values in the compose file and re-run the securityadmin script.

## How it is integrated with GLPI

- **Shared compose network.** Wazuh sits on the same network as `glpi`, so a
  Wazuh integration script can reach `http://glpi:80` (GLPI REST API) to open a
  ticket per alert, and GLPI can query the Wazuh API at
  `https://wazuh.manager:55000`.
- **Agents on the assets.** Install the Wazuh agent on each GLPI-tracked
  machine pointing at this host (`1514`/`1515`); the agent's inventory
  (syscollector) and the GLPI Agent inventory then describe the same estate.
- **Application-level sync** is configured afterwards: a GLPI plugin or a
  Wazuh integration (`integrations/` / `<integration>` block) that pushes
  alerts into GLPI's API with an API token (GLPI: Setup > General > API).

## Install the Wazuh agent on macOS

Apple silicon (use `...intel64.pkg` on Intel). Set `WAZUH_MANAGER` to this
Docker host's LAN/public IP:

    curl -O https://packages.wazuh.com/4.x/macos/wazuh-agent-4.14.7-1.arm64.pkg
    echo "WAZUH_MANAGER='<THIS_HOST_IP>'" > /tmp/wazuh_envs
    sudo installer -pkg wazuh-agent-4.14.7-1.arm64.pkg -target /
    sudo /Library/Ossec/bin/wazuh-control start

Then confirm the agent shows up under *Agents* in the dashboard.

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

# Wazuh

docker compose -f wazuh/generate-indexer-certs.yml run --rm generator
docker compose up -d