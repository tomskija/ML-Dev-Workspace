# P = one or more project names from projects.json (ppml, petro, weather, pointcloud)
# Leave P empty to act on everything.
P ?=

.PHONY: help generate check clone up stop down ps logs shell test clean

help:
	@echo "make generate          rebuild docker-compose.yml, devcontainers and calculators.json from projects.json"
	@echo "make clone             clone any project repos that are missing"
	@echo "make up [P=...]        build and start projects with their APIs and the UI (MLflow/Postgres come up automatically)"
	@echo "make stop [P=...]      stop projects without removing them"
	@echo "make down              stop and remove everything (MLflow history and Postgres data are kept)"
	@echo "make ps                what's running"
	@echo "make logs P=name       follow logs for one project"
	@echo "make shell P=name      bash inside a project container"
	@echo "make test P=name       run that project's pytest suite"
	@echo "make clean             down plus delete MLflow history and Postgres data"

generate:
	python3 generate.py

check:
	python3 generate.py --check

clone:
	python3 scripts/clone_projects.py

up:
	docker compose up -d --build $$(python3 generate.py --services $(P))

stop:
	docker compose stop $(P)

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f $(P)

shell:
	docker compose exec $(P) bash

test:
	docker compose exec $(P) pytest tests -v

clean:
	docker compose down -v
