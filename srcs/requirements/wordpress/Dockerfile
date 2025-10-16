FROM debian:bookworm

RUN apt-get update -y
RUN apt-get install -y curl 
RUN apt-get install -y wget 
RUN apt-get install -y php \
	php-fpm \
	php-mysql \
	mariadb-client \
	default-mysql-client

RUN wget https://fr.wordpress.org/wordpress-6.0-fr_FR.tar.gz -P /var/www
RUN cd /var/www && tar -xzf wordpress-6.0-fr_FR.tar.gz && rm wordpress-6.0-fr_FR.tar.gz
RUN chown -R root:root /var/www/wordpress

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/.
COPY tools/init_wordpress.sh /tmp/init_wordpress.sh

RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
RUN chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp

ENTRYPOINT [ "sh", "/tmp/auto_config.sh" ]