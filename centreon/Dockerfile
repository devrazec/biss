# Centreon 24.10 (LTS) central server.
#
# Centreon is packaged for full Linux distros, not as a container: it runs many
# services (Apache, php-fpm, MariaDB, centengine, cbd/broker, gorgone,
# centreontrapd, snmpd) under systemd. This image therefore runs systemd as PID 1
# and needs a privileged / cgroup-host container (see docker-compose.yml).
FROM debian:12

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive
ARG TZ=UTC

# --- systemd + base tooling ------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        systemd systemd-sysv dbus dbus-user-session \
        ca-certificates curl wget gnupg2 lsb-release apt-transport-https \
        procps cron sudo \
    && rm -rf /var/lib/apt/lists/*

# Mask units that make no sense inside a container
RUN systemctl mask \
        systemd-udevd systemd-udevd-kernel.socket systemd-udevd-control.socket \
        systemd-logind getty@tty1 console-getty getty.target \
        systemd-remount-fs dev-hugepages.mount sys-fs-fuse-connections.mount \
        systemd-firstboot.service

# --- repositories: Sury PHP, MariaDB 10.11, Centreon 24.10 ----------------
RUN echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list \
    && wget -qO- https://packages.sury.org/php/apt.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/php.gpg \
    && curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- \
         --os-type=debian --os-version=12 --mariadb-server-version="mariadb-10.11" \
    && echo "deb https://packages.centreon.com/apt-standard-24.10-stable/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/centreon.list \
    && echo "deb https://packages.centreon.com/apt-plugins-stable/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/centreon-plugins.list \
    && wget -qO- https://apt-key.centreon.com | gpg --dearmor > /etc/apt/trusted.gpg.d/centreon.gpg

# --- Centreon central + bundled MariaDB ----------------------------------
RUN apt-get update \
    && apt-get install -y centreon-mariadb centreon \
    && rm -rf /var/lib/apt/lists/*

# --- configuration ------------------------------------------------------
RUN printf '[server]\ninnodb_file_per_table=1\nopen_files_limit=32000\n' \
        > /etc/mysql/mariadb.conf.d/80-centreon.cnf \
    && sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf \
    && echo "date.timezone = ${TZ}" > /etc/php/8.2/mods-available/centreon-timezone.ini \
    && phpenmod centreon-timezone \
    && systemctl enable mariadb php8.2-fpm apache2 centreon cbd centengine \
        gorgoned centreontrapd snmpd snmptrapd

# --- first-boot DB preparation for the web installer -------------------
COPY db-init.sql    /usr/local/share/centreon/db-init.sql
COPY db-init.sh     /usr/local/bin/db-init.sh
COPY db-init.service /etc/systemd/system/db-init.service
RUN chmod +x /usr/local/bin/db-init.sh \
    && systemctl enable db-init.service

VOLUME [ "/sys/fs/cgroup", "/run", "/run/lock", "/tmp" ]
STOPSIGNAL SIGRTMIN+3
EXPOSE 80
CMD [ "/sbin/init" ]
