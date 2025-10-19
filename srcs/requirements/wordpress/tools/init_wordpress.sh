#!/bin/bash

DB_NAME="${DB_NAME}"
DB_USERNAME="${DB_USERNAME}"
DB_HOST="${DB_HOST:-mariadb:3306}"
DB_PASSWORD="$(cat /run/secrets/db_password)"

DOMAIN_NAME="${DOMAIN_NAME}"
WP_TITLE="${WP_TITLE}"
WP_ADMIN_USER_USERNAME="${WP_ADMIN_USER_USERNAME}"
WP_ADMIN_MAIL="${WP_ADMIN_MAIL}"
WP_ADMIN_PASSWORD="$(cat /run/secrets/admin_user_password)"

WP_USER_USERNAME="${WP_USER_USERNAME}"
WP_USER_MAIL="${WP_USER_MAIL}"
WP_USER_PASSWORD="$(cat /run/secrets/user_password)"
WP_USER_DISPLAY_NAME="${WP_USER_DISPLAY_NAME}"

echo "Waiting for MariaDB at $DB_HOST ..."
for i in $(seq 1 60); do
  if mysqladmin -h"${DB_HOST%:*}" -P"${DB_HOST#*:}" -u"$DB_USER" -p"$DB_PASSWORD" ping >/dev/null 2>&1; then
    echo "MariaDB is ready."
    break
  fi
  sleep 2
done

# Check if WordPress is already installed
if [ ! -f /var/www/wordpress/wp-config.php ]; then
	# Create the wp-config.php file
    echo "Creating wp-config.php file"
	wp config create --allow-root --dbname="$DB_NAME" --dbuser="$DB_USERNAME" --dbpass="$DB_PASSWORD" \
        --dbhost="mariadb:3306" --path="/var/www/wordpress"

    # Installer WordPress
	wp core install --allow-root --url="$DOMAIN_NAME" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER_USERNAME" \
		--admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_MAIL" --path="/var/www/wordpress"
fi

if ! wp user exists "$WP_USER_USERNAME" --allow-root --path="/var/www/wordpress" 2>/dev/null; then
    echo "Creating non-admin user: $WP_USER_USERNAME"
    wp user create "$WP_USER_USERNAME" "$WP_USER_MAIL" --user_pass="$WP_USER_PASSWORD" \
        --role="subscriber" --display_name="$WP_USER_DISPLAY_NAME" --allow-root --path="/var/www/wordpress"
else
    echo "User $WP_USER_USERNAME already exists"
fi

# Démarrer le serveur php-fpm
exec /usr/sbin/php-fpm8.2 -F