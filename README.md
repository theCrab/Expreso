# Expreso
This is an Cursor like AI first -- scaffold a headless REST Express API starter stack that includes Postgres and Redis with Unit and Integration test (Jest).  

## Configurations
NPM `package.json`
```json
"scripts": {
  "migrate:up": "node-pg-migrate up -f migration.config.json",
  "migrate:down": "node-pg-migrate down -f migration.config.json",
  "migrate:create": "node-pg-migrate create -f migration.config.json"
}
```
