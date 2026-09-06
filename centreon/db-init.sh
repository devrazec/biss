#!/bin/sh
# Applies db-init.sql to the bundled MariaDB, once, on first container start.
# Wired to systemd via db-init.service.
set -eu

MARKER="/var/lib/mysql/.centreon-db-init.done"   # lives on the centreon_db volume
SQL_SRC="/usr/local/share/centreon/db-init.sql"

[ -f "$MARKER" ] && exit 0

# Wait for the local MariaDB socket to accept connections.
i=0
while ! mysqladmin --protocol=socket ping >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -ge 60 ] && { echo "db-init: MariaDB did not come up" >&2; exit 1; }
    sleep 1
done

# Root may still be passwordless (fresh datadir) or already set (re-run).
if mariadb -uroot -e 'SELECT 1' >/dev/null 2>&1; then
    set -- -uroot
elif mariadb -uroot -proot -e 'SELECT 1' >/dev/null 2>&1; then
    set -- -uroot -proot
else
    echo "db-init: cannot authenticate to MariaDB as root" >&2
    exit 1
fi

mariadb "$@" < "$SQL_SRC"

touch "$MARKER"
echo "db-init: MariaDB prepared for the Centreon installer (root / root)"
