# messenger

A small full-stack chat app in Gleam: a Lustre frontend, a wisp/mist backend,
Postgres for storage, websockets for realtime updates, and account auth
(argon2id passwords + bearer-token sessions).

## Layout

```
shared/   target-agnostic — the Message type + JSON encode/decode (used by both sides)
server/   erlang target    — wisp + mist, pog (Postgres), websocket hub
client/   javascript target — lustre SPA
compose.yaml                — Postgres for local dev
```

`shared` is the payoff of full-stack Gleam: the wire types are defined once and
imported by both `client` and `server`, so the format can't drift.

The DB layer uses **pog** (client), **squirrel** (type-safe queries generated
from `server/src/server/db/sql/*.sql`), and **cigogne** (migrations in
`server/priv/migrations/`). The `server/db/{users,sessions,messages}` modules are
the typed repository API that maps squirrel's generated rows to the `shared`
types.

## Running

```sh
docker compose up -d
cd server && gleam run -m cigogne all   # apply migrations (creates the schema)
cd server && gleam run                  # start the API + websocket server
cd client && gleam run -m lustre/dev start
```

Working on the DB layer:

```sh
# after editing a migration / adding a table
cd server && gleam run -m cigogne all          # or `up` / `down` for one step
# after editing or adding a query in db/sql/*.sql (needs the DB running)
cd server && DATABASE_URL=postgres://messenger:messenger@localhost:5433/messenger \
  gleam run -m squirrel                        # regenerate db/sql.gleam
```

## Auth

- Register/login at `/register` and `/login`; chat at `/` is gated (routing via
  `modem`). The session token lives in `localStorage` and rides as
  `Authorization: Bearer <token>` (and `?token=` on the websocket).
- Passwords are argon2id (`argus`); tokens are stored in a `sessions` table.
- Messages are authored by `user_id` (the logged-in user, not client-supplied),
  and only the author can delete their own. `sender` is the joined username.
