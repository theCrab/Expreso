# Expreso
This is an Cursor like AI first -- scaffold a headless REST Express API starter stack that includes Postgres and Redis with Unit and Integration test (Jest).  

## Configurations
NPM `package.json`
```json
"scripts": {
  "migrate:up": "node-pg-migrate up -f migration.config.json",
  "migrate:down": "node-pg-migrate down -f migration.config.json",
  "migrate:create": "node-pg-migrate create -f migration.config.json",
  "typecheck": "tsc --noEmit",
  "test": "jest",
},
"lint-staged": {
  "*.ts": [
    "eslint --fix",
    "prettier --write"
  ]
},
```

### Run installation
```bash
npx husky init

npm install twilio @sendgrid/mail
npm install --save-dev @types/node

npx lint-staged
npm run typecheck
npm test
```

### Quickstart Commands
With your `Makefile` and `docker-compose.yml` in place, you can execute the following workflow directly from your terminal:
```bash
// Spin up your database and cache:
make up

// Run typechecks, linter, and TDD tests:
make typecheck
make lint
make test

// Tear down containers when done:
make down
```
