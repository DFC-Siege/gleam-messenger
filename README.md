# messenger

A small full-stack chat app in Gleam. The entire UI runs **server-side as a
single [Lustre server component](https://hexdocs.pm/lustre/)**: the browser
loads a thin runtime that connects over a WebSocket, and the server ships DOM
patches to it. Realtime updates fall out for free — a new message becomes a
model update becomes a DOM patch — with no custom socket plumbing.

Backed by wisp/mist, Postgres for storage, and account auth (argon2id passwords
+ token sessions).

## Layout

```
shared/   target-agnostic — Message/User/Event types + credential validation
server/   erlang target    — wisp + mist, pog (Postgres), the Lustre server component
compose.yaml                — Postgres for local dev
```

`shared` holds the types used across the app. The server-side Lustre app lives
under `server/src/server/`:

- `app.gleam` — the server component (`init`/`update`/`view`). It talks to the
  DB and the `hub` directly; auth, sending and deleting all happen in `update`.
- `app/state.gleam` — `Model`/`Msg`/`View` (kept separate so the views and the
  app can share them without an import cycle).
- `views/`, `ui/` — the Lustre view functions (target-agnostic).
- `live.gleam` — bridges a mist WebSocket to a per-connection server-component
  runtime (decodes client messages in, encodes DOM patches out).
- `page.gleam` — the HTML shell: the Lustre runtime, the
  `<lustre-server-component>` element, and a small script that keeps the session
  token in `localStorage` and feeds it into the connect URL.
- `router.gleam` — serves the shell and the static CSS. There is no REST API.
- `hub.gleam` — the pub/sub actor every connected component subscribes to.

The DB layer uses **pog**, **squirrel** (type-safe queries generated from
`server/src/server/db/sql/*.sql`), and **cigogne** (migrations in
`server/priv/migrations/`). The `server/db/{users,sessions,messages}` modules
map squirrel's rows to the `shared` types.

## Running

```sh
docker compose up -d                          # Postgres
cd server
gleam run -m cigogne all                       # apply migrations (creates the schema)
./.lustre/bin/tailwindcss-linux-x64/tailwindcss-linux-x64 \
  -i styles/app.css -o priv/static/app.css --minify   # build the CSS
gleam run                                      # start the server on :8000
```

Then open <http://localhost:8000>. Open a second browser to see messages appear
live in both.

The CSS is built with the Tailwind v4 standalone binary (the same one Lustre's
dev tools fetch). If it isn't present, download it from the
[Tailwind releases](https://github.com/tailwindlabs/tailwindcss/releases) for
your platform.

Working on the DB layer:

```sh
cd server && gleam run -m cigogne all          # or `up` / `down` for one step
# after editing or adding a query in db/sql/*.sql (needs the DB running)
cd server && DATABASE_URL=postgres://messenger:messenger@localhost:5433/messenger \
  gleam run -m squirrel                        # regenerate db/sql.gleam
```

## Auth

- Login/register happen inside the server component (`app.update`). On success a
  session token is minted, persisted to the `sessions` table, and emitted to the
  browser, which stores it in `localStorage` and reconnects with `?token=` so the
  session survives reloads.
- Passwords are argon2id (`argus`).
- Messages are authored by the logged-in `user_id` (never client-supplied), and
  only the author can delete their own. `sender` is the joined username.
