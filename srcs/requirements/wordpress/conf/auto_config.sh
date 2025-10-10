echo "Waiting for Mariadb..."
until mysqladmin ing -h mariadb --silent; do
	echo "Mariadb not available yet - waiting"
	sleep 3
done
echo "MariaDB is ready - Execute Command:"

if [ -f "/var/www/html/wp-config.php" ]; then
	echo "Wordpress is alredy Intalled"
else
	if [! -x /usr/local/bin/wp ]; then
		echo "Installing CLI"
		wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp
		chmod +x /usr/local/bin/wp
	fi

	wp core download --path=/var/www/html --allow-root
	wp config create --dbname=$MYSQL_DATABASE --dbuser=$MYSQL_USER --dbpass=$MYSQL_PASSWORD --dbhost=mariadb:3306 --path=/var/www/html --skip-check --allow-root
	wp core install \
		--path=/var/www/html \
		--url="https://$DOMAIN_NAME" \
		--title="$WP_TITLE" \
		--admin_user="$WP_USER" \
		--admin_password="$WP_PASSWORD" \
		--admin_email="$WP_ADMIN_EMAIL" \
		--skip-email \
		--allow-root
fi

if wp user get admin --path=/var/www/html --allow-root > /dev/null 2>&1; then
	echo "Deleting user 'Admin'"
	wp user delete admin --path=/var/www/html --allow-root --yes
fi

if ! wp user get "$WP_USER" --path=/var/www/html --allow-root > /dev/null 2>&1; then
	echo "Creating admin user '$WP_USER'"
	wp user create "$WP_USER" "$WP_EMAIL" --role=administrator --user_pass="$WP_PASSWORD" --path=/var/www/html --allow-root
else
	echo "Admin user $WP_USER already exists."
fi

echo "Starting Php-fpm"
exec /usr/sbin/php-fpm8.2 -F