#!/bin/sh
set -eu

# -e = Exit the script on error
# -u = Treat non-set ENV as errors

# Config (keep socket path consistent everywhere)
DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

# Secrets (files mounted via docker secrets)
DB_ROOT_PASS="$(cat /run/secrets/db_root_password)"
DB_PASS="$(cat /run/secrets/db_password)"

# Create runtime dirs / ownership
mkdir -p "$(dirname "$SOCKET")"
chown -R mysql:mysql "$(dirname "$SOCKET")"

mkdir -p "$DATADIR"
chown -R mysql:mysql "$DATADIR"

# Wait helper for the local socket
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

# First-run check
if [ ! -d "$DATADIR/mysql" ]; then
  echo "Initializing fresh MariaDB datadir..."
  mariadb-install-db --user=mysql --datadir="$DATADIR"

  # Start temporary server (socket-only, no TCP) — IPC, not TCP
  mysqld --skip-networking --socket="$SOCKET" --datadir="$DATADIR" --user=mysql &
  pid="$!"
  trap 'kill "$pid" 2>/dev/null || true' EXIT

  wait_for_socket

  # Creates the Wordpress Database, sets the two users (Root + User), sets their password and their rights
  echo "Securing root and creating database/user..."
  mysql --protocol=socket --socket="$SOCKET" <<SQL
-- Set a password for the local root account (no remote root account is created)
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';

-- Create the application database if it doesn't already exist
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Create the application user (host-scoped to the Docker network as needed)
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASS}';

-- Grant only the privileges WordPress needs on its own database (no global privileges, no GRANT OPTION)
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP
  ON \`${MYSQL_DATABASE}\`.*
  TO '${MYSQL_USER}'@'%';

-- Apply privilege changes
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

# Run real server in foreground (PID 1)
exec mariadbd --user=mysql --datadir="$DATADIR" --console
