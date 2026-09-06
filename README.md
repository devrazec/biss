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
