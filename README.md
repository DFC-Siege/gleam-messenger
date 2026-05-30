# messenger

A small full-stack chat app in Gleam: a Lustre frontend, a wisp/mist backend,
Postgres for storage, and websockets for realtime updates.

## Layout

```
shared/   target-agnostic — the Message type + JSON encode/decode (used by both sides)
server/   erlang target    — wisp + mist, pog (Postgres), websocket hub
client/   javascript target — lustre SPA
compose.yaml / db/init.sql  — Postgres for local dev
```

`shared` is the payoff of full-stack Gleam: the wire types are defined once and
imported by both `client` and `server`, so the format can't drift.

## Running

```sh
docker compose up -d
cd server && gleam run
cd client && gleam run -m lustre/dev start
```
