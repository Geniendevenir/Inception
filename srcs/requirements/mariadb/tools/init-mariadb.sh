#!/bin/sh
set -e

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# Utilise les variables d'environnement directement, exemple:
echo "Creating DB $MYSQL_DATABASE and user $MYSQL_USER"

if [ ! -d "/var/lib/mysql/mysql" ]; then
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql
  mysqld --skip-networking --socket=/var/run/mysqld/mysqld.sock &
  pid="$!"

  until mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent; do
    sleep 1
  done

  # Remplacer les placeholders dans /tmp/init.sql
  sed -i "s|MYSQL_DATABASE|$MYSQL_DATABASE|g" /tmp/init.sql
  sed -i "s|MYSQL_USER|$MYSQL_USER|g" /tmp/init.sql
  sed -i "s|MYSQL_PASSWORD|$MYSQL_PASSWORD|g" /tmp/init.sql
  sed -i "s|MYSQL_ROOT_PASSWORD|$MYSQL_ROOT_PASSWORD|g" /tmp/init.sql

  mysql < /tmp/init.sql

  mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

  mysqladmin shutdown --socket=/var/run/mysqld/mysqld.sock
  wait $pid
  echo "Database initialized."
else
  echo "Database already exists."
fi


exec mariadbd --user=mysql --console