import gleam/dynamic/decode
import gleam/http.{Delete, Get, Options, Post}
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import pog
import server/auth
import server/db/messages
import server/db/sessions
import server/db/users
import server/hub.{type Hub}
import shared/event
import shared/message
import shared/user.{type User, to_json as user_json}
import wisp.{type Request, type Response}

pub type Context {
  Context(db: pog.Connection, hub: Hub)
}

pub fn handle_request(ctx: Context, req: Request) -> Response {
  case req.method {
    Options -> add_cors(wisp.response(204))
    _ -> add_cors(handle(ctx, req))
  }
}

fn handle(ctx: Context, req: Request) -> Response {
  case request.path_segments(req) {
    ["api", "register"] -> register(ctx, req)
    ["api", "login"] -> login(ctx, req)
    ["api", "session"] -> logout(ctx, req)
    ["api", "me"] -> me(ctx, req)
    ["api", "messages"] -> messages(ctx, req)
    ["api", "messages", id] -> message(ctx, req, id)
    ["api", "crash"] -> {
      hub.crash(ctx.hub)
      wisp.response(204)
    }
    _ -> wisp.not_found()
  }
}

// --- auth ---

fn register(ctx: Context, req: Request) -> Response {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_json(req)

  case decode.run(body, credentials_decoder()) {
    Ok(#(username, password)) ->
      case users.create(ctx.db, username, auth.hash_password(password)) {
        Ok(user) -> issue_session(ctx, user, 201)
        Error(_) -> wisp.response(409)
      }
    Error(_) -> wisp.bad_request("expected {username, password}")
  }
}

fn login(ctx: Context, req: Request) -> Response {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_json(req)

  case decode.run(body, credentials_decoder()) {
    Ok(#(username, password)) ->
      case users.find_by_username(ctx.db, username) {
        Ok(#(user, hash)) ->
          case auth.verify_password(password, hash) {
            True -> issue_session(ctx, user, 200)
            False -> wisp.response(401)
          }
        Error(_) -> wisp.response(401)
      }
    Error(_) -> wisp.bad_request("expected {username, password}")
  }
}

fn logout(ctx: Context, req: Request) -> Response {
  use <- wisp.require_method(req, Delete)

  case auth.bearer_token(req) {
    Ok(token) -> {
      sessions.delete(ctx.db, token)
      wisp.response(204)
    }
    Error(_) -> wisp.response(401)
  }
}

fn me(ctx: Context, req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  use user <- auth.require_user(ctx.db, req)

  user_json(user)
  |> json.to_string
  |> wisp.json_response(200)
}

fn issue_session(ctx: Context, user: User, status: Int) -> Response {
  let token = auth.generate_token()
  sessions.create(ctx.db, user.id, token)

  json.object([#("token", json.string(token)), #("user", user_json(user))])
  |> json.to_string
  |> wisp.json_response(status)
}

// --- messages ---

fn messages(ctx: Context, req: Request) -> Response {
  case req.method {
    Get -> list_messages(ctx, req)
    Post -> create_message(ctx, req)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn list_messages(ctx: Context, req: Request) -> Response {
  use _ <- auth.require_user(ctx.db, req)

  json.array(messages.all(ctx.db), message.to_json)
  |> json.to_string
  |> wisp.json_response(200)
}

fn create_message(ctx: Context, req: Request) -> Response {
  use user <- auth.require_user(ctx.db, req)
  use body <- wisp.require_json(req)

  case decode.run(body, body_decoder()) {
    Ok(text) -> {
      let created = messages.insert(ctx.db, user.id, text)
      hub.publish(ctx.hub, event.Created(created))

      created
      |> message.to_json
      |> json.to_string
      |> wisp.json_response(201)
    }
    Error(_) -> wisp.bad_request("expected {body}")
  }
}

fn message(ctx: Context, req: Request, id: String) -> Response {
  use <- wisp.require_method(req, Delete)
  use user <- auth.require_user(ctx.db, req)

  case int.parse(id) {
    Ok(id) ->
      case messages.author(ctx.db, id) {
        Ok(author_id) if author_id == user.id -> {
          messages.delete(ctx.db, id)
          hub.publish(ctx.hub, event.Deleted(id))
          wisp.response(204)
        }
        Ok(_) -> wisp.response(403)
        Error(_) -> wisp.not_found()
      }
    Error(_) -> wisp.bad_request("invalid id")
  }
}

// --- decoders / cors ---

fn credentials_decoder() -> decode.Decoder(#(String, String)) {
  use username <- decode.field("username", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(#(username, password))
}

fn body_decoder() -> decode.Decoder(String) {
  use body <- decode.field("body", decode.string)
  decode.success(body)
}

fn add_cors(resp: Response) -> Response {
  resp
  |> response.set_header("access-control-allow-origin", "*")
  |> response.set_header(
    "access-control-allow-methods",
    "GET, POST, DELETE, OPTIONS",
  )
  |> response.set_header(
    "access-control-allow-headers",
    "content-type, authorization",
  )
  |> response.set_header("access-control-max-age", "86400")
}
