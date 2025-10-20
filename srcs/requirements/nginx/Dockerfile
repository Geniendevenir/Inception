FROM debian:bookworm

RUN apt-get update -y
RUN apt-get install -y nginx
RUN apt-get install -y curl 

RUN rm -f /etc/nginx/conf.d/default.conf
RUN rm -rf /etc/nginx/sites-enabled/*
RUN rm -rf /etc/nginx/sites-available/*

RUN mkdir -p /etc/nginx/ssl
RUN apt-get install -y openssl
RUN openssl req -x509 -nodes -out /etc/nginx/ssl/adebert.crt -keyout /etc/nginx/ssl/adebert.key -subj "/C=FR/ST=Paris/L=Paris/O=42 School/OU=adebert/CN=adebert.42.fr/"
RUN mkdir -p /var/run/nginx
COPY conf/nginx.conf /etc/nginx/conf.d/nginx.conf

CMD [ "nginx", "-g", "daemon off;" ]