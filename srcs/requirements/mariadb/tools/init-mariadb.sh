#!/bin/sh
set -eu

# -e = Exit the script on error
# -u = Treat non-set ENV as errors

# Config (keep socket path consistent everywhere)
DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

# Secrets (files mounted via docker secrets)
DB_ADMIN_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"
DB_USERNAME="${DB_USERNAME}"

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

# Check if we need to initialize - look for a marker file instead of mysql dir
INIT_MARKER="$DATADIR/.initialized"

if [ ! -f "$INIT_MARKER" ]; then
  echo "Initializing fresh MariaDB datadir..."
  
  # Clean up any partial/corrupted data
  if [ -d "$DATADIR/mysql" ]; then
    echo "Removing corrupted/partial datadir..."
    rm -rf "$DATADIR"/*
  fi
  
  mariadb-install-db --user=mysql --datadir="$DATADIR"

  # Start temporary server (socket-only, no TCP) – IPC, not TCP
  mysqld --skip-networking --socket="$SOCKET" --datadir="$DATADIR" --user=mysql &
  pid="$!"
  trap 'kill "$pid" 2>/dev/null || true' EXIT

  wait_for_socket

  # Creates the Wordpress Database, sets the two users (Root + User), sets their password and their rights
  echo "Securing root and creating database/user..."
  mysql --socket="$SOCKET" -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ADMIN_PASSWORD}'; FLUSH PRIVILEGES;" && \
  mysql --socket="$SOCKET" -uroot -p${DB_ADMIN_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS wordpress; \
        CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}'; \
        GRANT ALL PRIVILEGES ON wordpress.* TO '${DB_USERNAME}'@'%'; \
        FLUSH PRIVILEGES;" && \
  mysqladmin --socket="$SOCKET" -u root -p${DB_ADMIN_PASSWORD} shutdown

  wait "$pid"
  trap - EXIT
  
  # Create marker file to indicate successful initialization
  touch "$INIT_MARKER"
  chown mysql:mysql "$INIT_MARKER"
  
  echo "Database Initialized."
else
  echo "MariaDB already initialized – skipping init."
fi

# Run real server in foreground (PID 1)
exec mariadbd --user=mysql --datadir="$DATADIR" --console