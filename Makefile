.PHONY: up down test lint typecheck migrate-up migrate-down migrate-create clean

# Start local infrastructure
up:
	docker compose up -d
	@echo "Postgres and Redis containers are up."

# Stop local infrastructure
down:
	docker compose down
	@echo "Containers stopped."

# Run database migrations up
migrate-up:
	npm run migrate:up

# Rollback last database migration
migrate-down:
	npm run migrate:down

# Create a new migration file (usage: make migrate-create name=add_indices)
migrate-create:
	npm run migrate:create -- $(name)

# Run typechecking
typecheck:
	npx tsc --noEmit

# Run ESLint and Prettier checks
lint:
	npx eslint "src/**/*.ts" "tests/**/*.ts"
	npx prettier --check "src/**/*.ts" "tests/**/*.ts"

# Run Jest TDD integration and unit tests
test:
	npm test

# Clean build artifacts and dependencies
clean:
	rm -rf dist coverage node_modules
