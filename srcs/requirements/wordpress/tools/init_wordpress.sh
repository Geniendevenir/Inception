#!/bin/sh
set -eu

# Map env + secrets to consistent variables
DB_HOST="${DB_HOST:-mariadb}"                # set in compose environment
DB_NAME="${MYSQL_DATABASE:?missing}"
DB_USER="${MYSQL_USER:?missing}"
DB_PASS="$(cat /run/secrets/db_password)"    # secret file

SITE_URL="https://${DOMAIN_NAME:?missing}"   # from .env
SITE_TITLE="${WP_DEFAULT_TITLE:-My 42 Inception}"
ADMIN_USER="${WP_ADMIN_USER:?missing}"
ADMIN_EMAIL="${WP_ADMIN_EMAIL:?missing}"
ADMIN_PASS="$(awk -F= '$1=="WP_ADMIN_PASSWORD"{print $2}' /run/secrets/credentials)"

WEBROOT="/var/www/html"

echo "Waiting for MariaDB at $DB_HOST:3306 ..."
# Pure TCP ping; no credentials needed in most setups
until mysqladmin ping -h "$DB_HOST" -P 3306 --silent; do
  echo "MariaDB not available yet - waiting"
  sleep 3
done
echo "MariaDB is ready - proceeding."

# Ensure wp-cli exists (safety net in case download ever failed)
if ! command -v wp >/dev/null 2>&1; then
  echo "Installing wp-cli fallback..."
  wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp
  chmod +x /usr/local/bin/wp
fi

# Download WordPress if missing
if [ ! -f "${WEBROOT}/wp-includes/version.php" ]; then
  echo "Downloading WordPress to ${WEBROOT} ..."
  wp core download --path="${WEBROOT}" --allow-root
fi

# Create wp-config.php if missing
if [ ! -f "${WEBROOT}/wp-config.php" ]; then
  echo "Creating wp-config.php ..."
  wp config create \
    --dbname="${DB_NAME}" \
    --dbuser="${DB_USER}" \
    --dbpass="${DB_PASS}" \
    --dbhost="${DB_HOST}:3306" \
    --path="${WEBROOT}" \
    --skip-check \
    --allow-root
fi

# Install site if not installed yet
if ! wp core is-installed --path="${WEBROOT}" --allow-root; then
  echo "Installing WordPress ..."
  wp core install \
    --path="${WEBROOT}" \
    --url="${SITE_URL}" \
    --title="${SITE_TITLE}" \
    --admin_user="${ADMIN_USER}" \
    --admin_password="${ADMIN_PASS}" \
    --admin_email="${ADMIN_EMAIL}" \
    --skip-email \
    --allow-root
else
  echo "WordPress already installed."
fi

# Optional: cleanup or enforce admin account policy
if wp user get admin --path="${WEBROOT}" --allow-root >/dev/null 2>&1; then
  echo "Deleting default 'admin' user (hardening) ..."
  wp user delete admin --path="${WEBROOT}" --allow-root --yes || true
fi

echo "Starting PHP-FPM ..."
exec /usr/sbin/php-fpm8.2 -F
