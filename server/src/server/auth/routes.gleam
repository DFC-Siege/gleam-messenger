import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post}
import gleam/json
import server/auth
import server/context.{type Context}
import server/db/sessions
import server/db/users
import shared/credentials
import shared/user.{type User, to_json as user_json}
import wisp.{type Request, type Response}

pub fn register(ctx: Context, req: Request) -> Response {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_json(req)

  case decode.run(body, credentials_decoder()) {
    Ok(#(username, password)) ->
      case credentials.validate(username, password) {
        Error(errors) -> unprocessable(errors)
        Ok(_) ->
          case users.create(ctx.db, username, auth.hash_password(password)) {
            Ok(user) -> issue_session(ctx, user, 201)
            Error(_) -> wisp.response(409)
          }
      }
    Error(_) -> wisp.bad_request("expected {username, password}")
  }
}

pub fn login(ctx: Context, req: Request) -> Response {
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

pub fn logout(ctx: Context, req: Request) -> Response {
  use <- wisp.require_method(req, Delete)

  case auth.bearer_token(req) {
    Ok(token) -> {
      sessions.delete(ctx.db, token)
      wisp.response(204)
    }
    Error(_) -> wisp.response(401)
  }
}

pub fn me(ctx: Context, req: Request) -> Response {
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

fn unprocessable(errors: List(credentials.Error)) -> Response {
  json.array(errors, fn(error) { json.string(credentials.message(error)) })
  |> json.to_string
  |> wisp.json_response(422)
}

fn credentials_decoder() -> decode.Decoder(#(String, String)) {
  use username <- decode.field("username", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(#(username, password))
}
