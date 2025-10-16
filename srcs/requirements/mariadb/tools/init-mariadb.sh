#!/bin/sh
set -eu

# ===== Config (keep socket path consistent everywhere) =====
SOCKET="/run/mysqld/mysqld.sock"
DATADIR="/var/lib/mysql"

# ===== Secrets (files mounted via docker secrets) =====
DB_ROOT_PASS="$(cat /run/secrets/db_root_password)"
DB_PASS="$(cat /run/secrets/db_password)"

# ===== Create runtime dirs / ownership =====
mkdir -p "$(dirname "$SOCKET")"
chown -R mysql:mysql "$(dirname "$SOCKET")"

mkdir -p "$DATADIR"
chown -R mysql:mysql "$DATADIR"

# ===== Wait helper for the local socket =====
wait_for_socket() {
  for i in $(seq 1 60); do
    if mysqladmin --socket="$SOCKET" ping >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for mysqld socket" >&2
  return 1
}

# ===== First-run check =====
if [ ! -d "$DATADIR/mysql" ]; then
  echo "Initializing fresh MariaDB datadir..."
  mariadb-install-db --user=mysql --datadir="$DATADIR"

  # Start temporary server (socket-only, no TCP) — IPC, not TCP
  mysqld --skip-networking --socket="$SOCKET" --datadir="$DATADIR" --user=mysql &
  pid="$!"
  trap 'kill "$pid" 2>/dev/null || true' EXIT

  wait_for_socket

  echo "Securing root and creating database/user..."
  mysql --protocol=socket --socket="$SOCKET" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';

-- Optional: remote root (remove if your policy forbids this)
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${DB_ROOT_PASS}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

  # Clean shutdown of the temp server
  mysqladmin --protocol=socket --socket="$SOCKET" -uroot -p"$DB_ROOT_PASS" shutdown
  wait "$pid"
  trap - EXIT
  echo "Database Initialized."
else
  echo "Existing MariaDB datadir detected — skipping init."
fi

# ===== Run real server in foreground (PID 1) =====
exec mariadbd --user=mysql --datadir="$DATADIR" --console
