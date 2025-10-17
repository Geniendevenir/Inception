FROM debian:bookworm

RUN apt-get update -y
RUN apt-get install -y nginx
RUN apt-get install -y curl 
RUN mkdir -p /etc/nginx/ssl
RUN apt-get install -y openssl
RUN openssl req -x509 -nodes -out /etc/nginx/ssl/adebert.crt -keyout /etc/nginx/ssl/adebert.key -subj "/C=FR/ST=Paris/L=Paris/O=42 School/OU=adebert/CN=adebert.42.fr/"
RUN mkdir -p /var/run/nginx
COPY conf/nginx.conf /etc/nginx/conf.d/nginx.conf

RUN chmod 755 /var/www/wordpress
RUN chown -R www-data:www-data /var/www/wordpress

CMD [ "nginx", "-g", "daemon off;" ]