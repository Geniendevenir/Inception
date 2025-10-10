#!/bin/sh
set -eu

# Get Secrets
DB_ROOT_PASS="$(cat /run/secrets/db_root_password)"
DB_PASS="$(cat /run/secrets/db_password)"

# Create Dir / Set Permissions
	# Temporary Socket
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld
	# Database Files
mkdir -p /var/lib/mysql
chown -R mysql:mysql /var/lib/mysql

wait_for_socket() {
	for i in $(seq 1 60); do
		if mysqladmin --socket=/var/run/mysqld/mysqld.sock pring >/dev/null 2>&1; then
			return 0
		fi
		sleep 1
	done
	echo "Timed out waiting for mysqld socket" >&2
	return 1
}



