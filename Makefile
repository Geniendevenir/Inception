COMPOSE := docker compose -f srcs/docker-compose.yml --env-file srcs/.env
DATA_DIR := /home/allan/data
DB_DIR := $(DATA_DIR)/mariadb
WP_DIR := $(DATA_DIR)/wordpress

.PHONY: all up build down stop start clean fclean re ps

all: up

$(DB_DIR) $(WP_DIR):
	mkdir -p $(DB_DIR) $(WP_DIR)

up: $(DB_DIR) $(WP_DIR)
	$(COMPOSE) up -d --build

build:
	$(COMPOSE) build --no-cache

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v

fclean: down
	@echo "Removing data directories (Will erase data)"
	sudo rm -rf /home/allan/data/mariadb /home/allan/data/wordpress
	@echo "Data directories emptied."
	$(COMPOSE) down --volumes --rmi local	


re: fclean up

