.SILENT:
.PHONY: website test

help:
	{ grep --extended-regexp '^[a-zA-Z_-]+:.*#[[:space:]].*$$' $(MAKEFILE_LIST) || true; } \
	| awk 'BEGIN { FS = ":.*#[[:space:]]*" } { printf "\033[1;32m%-22s\033[0m%s\n", $$1, $$2 }'

env-create: # 1) create .env file
	./make.sh env-create

terraform-init: # 2) terraform init (updgrade) + validate
	./make.sh terraform-init

terraform-create: # 2) terraform create ecr repo + setup .env file
	./make.sh terraform-create

website: # 3) run website server using npm - dev mode
	./make.sh website

dev-build: # 4) build website-dev image
	./make.sh dev-build

dev-run: # 4) run website-dev image
	./make.sh dev-run

dev-stop: # 4) stop website-dev container
	./make.sh dev-stop

up: # 5) run the project using docker-compose (same as storage + convert + website commands)
	./make.sh up

down: # 5) stop docker-compose + remove volumes
	./make.sh down

prod-build: # 6) build website image
	./make.sh prod-build

prod-run: # 6) run website image
	./make.sh prod-run

prod-stop: # 6) stop website container
	./make.sh prod-stop

update-patch: # 6) update patch version
	./make.sh update-patch

ecr-push: # 7) push website image to ecr
	./make.sh ecr-push

increase-build-push: # 7) update-patch + ecr-push
	./make.sh increase-build-push

up-aws: # 7) run the project using docker-compose with latest images pushed on ecr
	./make.sh up-aws

down-aws: # 7) stop docker-compose + remove volumes
	./make.sh down-aws

terraform-destroy: # 8) terraform destroy ecr repo
	./make.sh terraform-destroy

clear: # 8) clear docker images
	./make.sh clear
