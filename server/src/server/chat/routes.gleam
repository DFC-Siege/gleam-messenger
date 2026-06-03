import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post}
import gleam/int
import gleam/json
import server/auth
import server/context.{type Context}
import server/db/messages
import server/hub
import shared/event
import shared/message
import wisp.{type Request, type Response}

pub fn collection(ctx: Context, req: Request) -> Response {
  case req.method {
    Get -> list_messages(ctx, req)
    Post -> create_message(ctx, req)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn single(ctx: Context, req: Request, id: String) -> Response {
  use <- wisp.require_method(req, Delete)
  use user <- auth.require_user(ctx.db, req)

  case int.parse(id) {
    Ok(id) ->
      case messages.author(ctx.db, id) {
        Ok(author_id) if author_id == user.id -> {
          messages.delete(ctx.db, id)
          hub.publish(ctx.hub, event.MessageDeleted(id))
          wisp.response(204)
        }
        Ok(_) -> wisp.response(403)
        Error(_) -> wisp.not_found()
      }
    Error(_) -> wisp.bad_request("invalid id")
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
      hub.publish(ctx.hub, event.MessageCreated(created))

      created
      |> message.to_json
      |> json.to_string
      |> wisp.json_response(201)
    }
    Error(_) -> wisp.bad_request("expected {body}")
  }
}

fn body_decoder() -> decode.Decoder(String) {
  use body <- decode.field("body", decode.string)
  decode.success(body)
}
