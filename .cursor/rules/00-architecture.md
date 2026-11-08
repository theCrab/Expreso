### Phase 0: Tooling scaffold (no behaviour)
Node LTS, Typescript strict `tsconfig`, Jest, supertest, ESLint with a snake_case filename rule, Prettier, Husky pre-commit (lint, types, tests), Postgres and Redis for tests, `.env.example`.
Exit: an empty suite runs green locally and in CI.

### Phase 1: App shell and config
- config loader throws a clear error when a required variable is missing
- config loader parses numbers and durations
- `GET /v1/health` returns 200 with a service name
- `GET /v1/health` returns 503 when Postgres is unreachable
- `GET /v1/health` returns 503 when Redis is unreachable
- unknown route returns the standard JSON error envelope
- malformed JSON body returns 400 in the standard envelope

---
## 2. API contract (version 1)

### Sign-in (existing users)

| Method | Path | Purpose | Success |
|---|---|---|---|
| POST | `/v1/auth/signin` | Step 1. Send an OTP to a phone or email | `202` generic |
| POST | `/v1/auth/signin/:otp` | Step 2. Exchange the OTP for the auth payload | `200` payload |

### Signup (new users in Redis store)

| Method | Path | Purpose | Success |
|---|---|---|---|
| POST | `/v1/auth/signup` | Submit email and phone. Sends one OTP to each, unless they belong to any existing user. Returns a `signup_id` | `202` |
| POST | `/v1/auth/signup/:signup_id` | Verify one channel (`email` or `phone`) with its OTP. The call that verifies the second channel creates the user and returns the auth payload | `200` with `status: pending`, or `200` the payload |

### Tokens and platform

| Method | Path | Purpose | Success |
|---|---|---|---|
| POST | `/v1/auth/refresh/:token` | Exchange a refresh token for a new pair | `200` payload |
| POST | `/v1/auth/signout` | Revoke a refresh token family | `204` |
| GET | `/v1/.well-known/jwks.json` | Public keys for host apps to verify access tokens offline | `200` |
| GET | `/v1/health` | Liveness, plus Postgres and Redis readiness | `200` |

**Auth payload (signin verify, signup verify on the second channel, refresh):** `user_id`, `access_token`, `refresh_token`, `token_type`, `expires_in`.
**Access token claims:** `sub` = `user_id`, `iss`, `aud`, `iat`, `exp`, `jti`.
**Refresh token:** opaque random string, never a JWT.

Behavioural rules:
- Signin request returns the same `202` whether or not the identifier belongs to a user, and sends nothing for unknown or inactive users.
- Signin verify and signup verify return one generic `401` for wrong, expired, consumed, locked or unknown codes, and for inactive users.
- Signup start behaves identically whether or not the email or phone is already registered: same `202`, same OTP message, same timing. Nothing in the API ever says "already registered".
- When both channels are verified, the outcome is decided by who the two identifiers belong to (proposed, see section 9):
  - neither belongs to a user: create the user, return the payload
  - they belong to exactly one user (one or both match): sign that user in and return the payload. A new identifier is not added to the existing account, because changing contact details belongs in a separate authenticated flow
  - they belong to two different users: create nothing, sign in nobody, return the generic failure
  - the matched user is inactive: the generic 401
- The first successful channel verification returns `status: pending`. Only the call that completes the pair returns a payload, so two parallel verifications can never create two users or issue two token sets.
- Errors use one consistent JSON envelope with a stable `code` field.

---
## 3. Architecture (MVC)
Models hold data access and domain rules. Controllers are thin HTTP adapters. Views shape JSON responses. Routes wire paths to controllers. Infrastructure sits in `services` behind interfaces/types so it can be swapped or faked.

Example app folder/file structure
```txt
├── .cursor/
│   └── rules/
│       ├── 01-architecture.mdc     # Architecture rules for your AI
│       └── 02-otp-auth.mdc         # Security & business logic constraints
├── src/
│   ├── config/
│   │   ├── database.ts             # Pg pool connection configuration
│   │   └── mailer.ts               # SendGrid and Twilio configuration
│   │   └── env.ts                  # ENV configuration
│   ├── controllers/
│   │   ├── auth.controller.ts      # HTTP layer: handle request/response (Signup, Verify)
│   │   └── auth.controller.ts      # HTTP layer: handle request/response (Signin, Signout, Refesh, Verify)
│   ├── middlewares/
│   │   ├── auth.middleware.ts      # JWT Validation check
│   │   └── error.middleware.ts     # Global catch-all error handling
│   ├── models/
│   │   └── user.model.ts           # Postgres Zod/SQL execution/Queries
│   ├── routes/
│   │   └── auth.routes.ts          # Express Route definitions, Validation
│   ├── services/
│   │   ├── auth.service.ts         # Core business logic: JWT & OTP verification
│   │   ├── notifier.service.ts     # Email and SMS logic layer
│   │   ├── otp.generator.service.ts # secure random numeric code
│   │   ├── otp.hasher.service.ts   # keyed hash bound to identifier and purpose
│   │   ├── otp.store.service.ts    # redis implementation and in-memory fake
│   │   ├── refresh_token.generator.service.ts
│   │   ├── token.issuer.service.ts # ES256 access tokens, JWKS publishing
│   │   ├── email.service.ts        # SendGrid abstraction layer
│   │   └── sms.service.ts          # Twilio abstraction layer
│   ├── types/
│   │   └── express.d.ts            # Extension for Request namespaces
│   ├── app.ts                      # Express app configuration
│   └── server.ts                   # App entrypoint & server start
├── tests/
│   ├── support/                    # Test db and Redis setup, fakes, factories
│   ├── unit/
│   │   └── auth.middleware.test.ts # JWT Validation test
│   └── integration/
│   │   └── error.middleware.test.ts # An integration test
├── docs/                           # openapi spec, runbook
├── .env.example                    # Template for environment secrets
├── docker-compose.yml              # app, Postgres and Redis, for local and tests
├── package.json
├── tsconfig.json
├── jest.config.ts
├── eslintrc.json
├── .prettierrc
└── .gitignore
```
Interfaces (each in `src/types/`, each with a fake in `tests/support/`): `user`, `otp_record`, `otp_store`, `signup_session`, `refresh_token_record`, `notifier`, `clock`, `otp_hasher`, `token_issuer`, `user_repository`, `refresh_token_repository`, `auth_payload`, `app_config`.

Typing rules: `strict` plus `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes`. No `any`. Interfaces for every object shape. Type aliases only where an interface cannot express it (unions, mapped types). Dependencies are passed in by constructor or factory function, never imported as globals inside models.

---

## 4. Data

### Postgres

**users**: `id`, `phone`, `email`, `is_active`, `created_at`, `updated_at`.
- Both `phone` and `email` are required at signup, so both are non-null and unique. Phone is stored in E.164, email lower-cased.
- `is_active` defaults to true.
- `updated_at` changes on update.

**refresh_tokens**: `id`, `user_id`, `token_hash`, `family_id`, `expires_at`, `revoked_at`, `replaced_by_id`, `created_at`. Postgres, not Redis, because these live for weeks and must survive a cache flush.

### Redis-like store (records deleted on success or expiry)
**otps**: `otp_hash`, `otp_expires_at`, `attempts`. The store also sets a TTL equal to the expiry, so expired records disappear on their own. The explicit `otp_expires_at` is still stored and checked against the injected clock so behaviour is testable.

**signup_sessions** (new, short-lived): `signup_id`, `email`, `phone`, `email_verified`, `phone_verified`, with a TTL (default 15 minutes). Deleted on completion.

Migrations (`src/config/database/migrations/...`) are plain SQL files, tested by applying them to an empty database in CI.

---


