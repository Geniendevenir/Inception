FROM debian:bookworm

RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y mariadb-server
RUN apt-get install -y vim
COPY /conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# add and exec script mariadb installation
COPY /tools/init-mariadb.sh /tmp/init-mariadb.sh
COPY /conf/init.sql /tmp/init.sql

RUN chown -R mysql:mysql /etc/mysql && chmod +x /tmp/init-mariadb.sh

ENTRYPOINT ["sh", "/tmp/init-mariadb.sh"]