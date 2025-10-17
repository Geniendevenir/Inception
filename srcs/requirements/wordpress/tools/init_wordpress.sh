#!/bin/bash

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/admin_user_password)"
WP_USER_PASSWORD="$(cat /run/secrets/user_password)"

sleep 10

# Check if WordPress is already installed
if [ ! -f /var/www/html/wordpress/wp-config.php ]; then
	# Create the wp-config.php file
    echo "Creating wp-config.php file"
	wp config create --allow-root --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASSWORD" \
        --dbhost="mariadb:3306" --path="/var/www/html/wordpress"

    # Installer WordPress
	wp core install --allow-root --url="$DOMAIN_NAME" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" \
		--admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_MAIL" --path="/var/www/html/wordpress"
fi

if ! wp user exists "$WP_USER_USERNAME" --allow-root --path="/var/www/html/wordpress" 2>/dev/null; then
    echo "Creating non-admin user: $WP_USER_USERNAME"
    wp user create "$WP_USER_USERNAME" "$WP_USER_MAIL" --user_pass="$WP_USER_PASSWORD" \
        --role="subscriber" --display_name="$WP_USER_DISPLAY_NAME" --allow-root --path="/var/www/html/wordpress"
else
    echo "User $WP_USER_USERNAME already exists"
fi

# Démarrer le serveur php-fpm
exec /usr/sbin/php-fpm8.2 -F
