#!/bin/bash
set -e

WEBROOT="/var/www/html/wordpress"
DB_HOST="mariadb"
DB_PORT="3306"

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/admin_user_password)"
WP_USER_PASSWORD="$(cat /run/secrets/user_password 2>/dev/null || true)"

# Wait for MariaDB to be ready
until mysqladmin ping -h "$DB_HOST" -P "$DB_PORT" --silent; do
    echo "Waiting for MariaDB..."
    sleep 2
done
echo "MariaDB is ready."

# Create wp-config.php if it doesn’t exist
if [ ! -f "$WEBROOT/wp-config.php" ]; then
    echo "Creating wp-config.php..."
    wp config create --allow-root \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="${DB_HOST}:${DB_PORT}" \
        --path="$WEBROOT"

    echo "Installing WordPress..."
    wp core install --allow-root \
        --url="$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --path="$WEBROOT"
else
    echo "WordPress already configured."
fi

# Create optional non-admin user
if [ -n "${WP_USER_USERNAME:-}" ] && ! wp user exists "$WP_USER_USERNAME" --allow-root --path="$WEBROOT" 2>/dev/null; then
    echo "Creating non-admin user: $WP_USER_USERNAME"
    wp user create "$WP_USER_USERNAME" "$WP_USER_MAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --role="subscriber" \
        --display_name="${WP_USER_DISPLAY_NAME:-$WP_USER_USERNAME}" \
        --allow-root --path="$WEBROOT"
else
    echo "User $WP_USER_USERNAME already exists or not defined."
fi

# Run php-fpm in foreground
exec /usr/sbin/php-fpm8.2 -F
