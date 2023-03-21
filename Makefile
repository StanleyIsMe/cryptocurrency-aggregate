.PHONY: all clean help deploy test test-race test-leak bench bench-compare bench-swagger-gen lint sec-scan vuln-scan upgrade release release-tag changelog-gen changelog-commit proto-gen proto-lint

help: ## show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {sub("\\\\n",sprintf("\n%22c"," "), $$2);printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

PROJECT_NAME?=cryptocurrency-aggregate
API_NAME?=$(PROJECT_NAME)-api
MIGRATE_NAME?=$(PROJECT_NAME)-migrate
ENV_LIST?=local localdev dev staging production

SHELL = /bin/bash

########
# test #
########

test: ## launch all tests
	go test ./... -cover -race -leak

test-race: ## launch all tests with race detection
	go test ./... -cover -race

test-leak: ## launch all tests with leak detection
	go test ./... -leak

test-coverage-report: ## test with coverage report
	go test -v  ./... -cover -race -covermode=atomic -coverprofile=./coverage.out
	go tool cover -html=coverage.out

test-coveralls:
	go test -v ./... -race -leak -failfast -covermode=atomic -coverprofile=./coverage.out
	goveralls -covermode=atomic -coverprofile=./coverage.out -repotoken=$(COVERALLS_TOKEN)

#############
# benchmark #
#############

bench: ## launch benchs
	go test ./... -bench=. -benchmem | tee ./bench.txt

bench-compare: ## compare benchs results
	benchstat ./bench.txt

########
# lint #
########

lint: ## lints the entire codebase
	@golangci-lint run ./... --config=./.golangci.toml

#######
# sec #
#######

sec-scan: trivy-scan vuln-scan ## scan for security and vulnerability issues

trivy-scan: ## scan for sec issues with trivy (trivy binary needed)
	trivy fs --exit-code 1 --no-progress --severity CRITICAL ./

vuln-scan: ## scan for vulnerability issues with govulncheck (govulncheck binary needed)
	govulncheck ./...

############
# upgrades #
############

upgrade: ## upgrade dependencies (beware, it can break everything)
	go mod tidy && \
	go get -t -u ./... && \
	go mod tidy

#########
# build #
#########


###########
# release #
###########


#############
# changelog #
#############

MOD_VERSION = $(shell git describe --abbrev=0 --tags `git rev-list --tags --max-count=1`)

MESSAGE_CHANGELOG_COMMIT="chore(changelog): update CHANGELOG.md for $(MOD_VERSION)"

changelog-gen: ## generates the changelog in CHANGELOG.md
	@git cliff -o ./CHANGELOG.md && \
	printf "\nchangelog generated!\n"
	git add CHANGELOG.md

changelog-commit: ## commit CHANGELOG.md
	git commit -S -m $(MESSAGE_CHANGELOG_COMMIT) ./CHANGELOG.md

######
# db #
######

APP_NAME_UND=$(shell echo "$(API_NAME)" | tr '-' '_')

db-pg-init: ## create users and passwords in postgres for your app
	@( \
	printf "Enter pass for db: \n"; read -rs DB_PASSWORD &&\
	printf "Enter port(5436...): \n"; read -r DB_PORT &&\
	sed \
	-e "s/DB_PASSWORD/$$DB_PASSWORD/g" \
	-e "s/APP_NAME_UND/$(APP_NAME_UND)/g" \
	./database/init/init.sql | \
	PGPASSWORD=$$DB_PASSWORD psql -h localhost -p $$DB_PORT -U postgres -f - \
	)

db-cockroachdb-rootkey: ## create rootkey for cockroachdb
	mkdir ./db/crdb-certs && \
	kubectl cp cockroachdb/cockroachdb-0:cockroach-certs/ca.crt ./db/crdb-certs/ca.crt -c db && \
	cockroach cert create-client \
		--certs-dir=./db/crdb-certs \
		--ca-key=$(CAROOT)/rootCA-key.pem root

db-cockroachdb-init: ## create users and passwords in crdb for your app
	@( \
	printf "Enter pass for db: \n"; read -s DB_PASSWORD && \
	printf "Enter port(26257...): \n"; read -r DB_PORT &&\
	sed \
	-e "s/DB_PASSWORD/$$DB_PASSWORD/g" \
	./database/init/init.sql > ./db/crdb-certs/init.sed.sql && \
	cockroach sql --certs-dir=./db/crdb-certs -f ./db/crdb-certs/init.sed.sql -p $$DB_PORT && \
	rm ./db/crdb-certs/init.sed.sql \
	)

#######
# sql #
#######

sqlboiler: ## gen sqlboiler code for your app
	@( \
	printf "Enter pass for db: "; read -s DB_PASSWORD && \
	printf "Enter port(5432, 26257...): \n"; read -r DB_PORT && \
	PSQL_HOST=localhost PSQL_PORT=$$DB_PORT PSQL_PASS=$$DB_PASSWORD PSQL_DBNAME=$(APP_NAME_UND)_local PSQL_USER=$(APP_NAME_UND)_app sqlboiler psql -c ./database/sqlboiler/sqlboiler.toml && \
	go get -t golangreferenceapi/internal/db/sqlboiler && \
	PSQL_HOST=localhost PSQL_PORT=$$DB_PORT PSQL_PASS=$$DB_PASSWORD PSQL_DBNAME=$(APP_NAME_UND)_local PSQL_USER="postgres" PSQL_SSLMODE=disable go test ./internal/db/sqlboiler && \
	PSQL_HOST=localhost PSQL_PORT=$$DB_PORT PSQL_PASS=$$DB_PASSWORD PSQL_DBNAME=$(APP_NAME_UND)_local PSQL_USER=$(APP_NAME_UND)_app sqlboiler psql -c ./database/sqlboiler/sqlboiler.toml --no-tests=true && \
	go mod tidy \
	)

sqlc: ## gen sqlc code for your app
	sqlc generate -f ./database/sqlc/sqlc.yaml

##############
# migrations #
##############

migration-local-up: ## migration up
	@( \
	read -p "Are you sure you want to apply up migrations? [y/N]" -r -n 1; \
	echo ""; \
	if [[ $$REPLY =~ ^[yY]$$ ]]; then \
		go run ./cmd/migrate/*.go --script-mode=true up; \
	fi; \
	)

migration-local-down: ## migration down
	@( \
	read -p "Are you sure you want to apply down migrations? [y/N]" -r -n 1; \
	echo ""; \
	if [[ $$REPLY =~ ^[yY]$$ ]]; then \
		go run ./cmd/migrate/*.go --script-mode=true down; \
	fi; \
	)


###########
# swagger #
###########

swagger-gen: ## gen swagger docs for your API
	swag init \
		-g rest.go \
		-d ./cmd/api \
		--parseDependency \
		--outputTypes go \
		--output "./internal/payment/docs/"


#############
# proto-gen #
#############

proto-gen: proto-lint ## gen protobuf code
	@printf "Generating protos files....\n"
	@buf generate --error-format=json

proto-lint: ## lint protobuf with buf
	@printf "Linting protos files...\n"
	@buf lint

proto-clean: ## remove proto gen files
	rm -rf ./internal/port/grpc/protos

############
# mock gen #
############

mock-gen: ## gen mocks
	go generate ./...

###########
#   GCI   #
###########
gci-format: ## format repo through gci linter
	gci write --skip-generated -s standard -s default -s "prefix(cryptocurrencyaggregate)" ./

