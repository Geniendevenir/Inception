FROM debian:bookworm

RUN apt-get update -y
RUN apt-get install -y mariadb-server
COPY conf/mariadb.conf /etc/mysql/mariadb.conf.d/mariadb.conf

# add and exec script mariadb installation
COPY tools/init-mariadb.sh /tmp/init-mariadb.sh

RUN chown -R mysql:mysql /etc/mysql && chmod +x /tmp/init-mariadb.sh

ENTRYPOINT ["sh", "/tmp/init-mariadb.sh"]