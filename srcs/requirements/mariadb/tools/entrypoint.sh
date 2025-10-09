#!/usr/bin/env bash

DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"
PIDFILE="/run/mysqld/mysqld.pid"

SQL_ROOT_PASSWORD="${SQL_ROOT_PASSWORD:-rootpass}"
SQL_DATABASE="${SQL_DATABASE:-wpdb}"
SQL_USER="${SQL_USER:-wpuser}"
SQL_PASSWORD="${SQL_PASSWORD:-wppass}"

mkdir -p /run/mysqld "$DATADIR"
chown -R mysql:mysql /run/mysqld "$DATADIR"

if [ ! -d "$DATADIR/mysql" ]; then
  echo "[init] Initializing database system tables..."
  mariadb-install-db --user=mysql --datadir="$DATADIR"
fi

echo "[init] Starting temporary MySQL (mysqld_safe)..."
mysqld_safe --datadir="$DATADIR" --socket="$SOCKET" --pid-file="$PIDFILE" --user=mysql &

for i in {1..60}; do
  mysqladmin --protocol=socket --socket="$SOCKET" ping >/dev/null 2>&1 && break
  sleep 1
done

if ! mysqladmin --protocol=socket --socket="$SOCKET" ping >/dev/null 2>&1; then
  echo "[init] MySQL failed to start for bootstrap." >&2
  exit 1
fi

echo "[init] Running bootstrap SQL (create DB/user, set root password)..."
mysql --protocol=socket --socket="$SOCKET" -u root -e "CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\`;"
mysql --protocol=socket --socket="$SOCKET" -u root -e "CREATE USER IF NOT EXISTS '${SQL_USER}'@'%' IDENTIFIED BY '${SQL_PASSWORD}';"
mysql --protocol=socket --socket="$SOCKET" -u root -e "GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO '${SQL_USER}'@'%';"
mysql --protocol=socket --socket="$SOCKET" -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';"
mysql --protocol=socket --socket="$SOCKET" -u root -p"${SQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

# --- Stop the temp server like the tutorial does ---
echo "[init] Shutting down temporary MySQL..."
mysqladmin --protocol=socket --socket="$SOCKET" -u root -p"${SQL_ROOT_PASSWORD}" shutdown

# --- Start the real server in foreground (container best practice) ---
echo "[run] Starting MySQL in foreground..."
exec mysqld_safe --datadir="$DATADIR" --socket="$SOCKET" --pid-file="$PIDFILE" --user=mysql