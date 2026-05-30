import gleam/dynamic/decode
import gleam/http.{Delete, Get, Options, Post}
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import pog
import server/db
import server/hub.{type Hub}
import shared/event
import shared/message
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
    ["api", "messages"] -> messages(ctx, req)
    ["api", "messages", id] -> message(ctx, req, id)
    _ -> wisp.not_found()
  }
}

fn messages(ctx: Context, req: Request) -> Response {
  case req.method {
    Get -> list_messages(ctx)
    Post -> create_message(ctx, req)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn list_messages(ctx: Context) -> Response {
  json.array(db.all(ctx.db), message.to_json)
  |> json.to_string
  |> wisp.json_response(200)
}

fn create_message(ctx: Context, req: Request) -> Response {
  use body <- wisp.require_json(req)

  case decode.run(body, new_message_decoder()) {
    Ok(#(sender, text)) -> {
      let created = db.insert(ctx.db, sender, text)
      hub.publish(ctx.hub, event.Created(created))

      created
      |> message.to_json
      |> json.to_string
      |> wisp.json_response(201)
    }
    Error(_) -> wisp.bad_request("expected {sender, body}")
  }
}

fn message(ctx: Context, req: Request, id: String) -> Response {
  use <- wisp.require_method(req, Delete)

  case int.parse(id) {
    Ok(id) -> {
      db.delete(ctx.db, id)
      hub.publish(ctx.hub, event.Deleted(id))
      wisp.response(204)
    }
    Error(_) -> wisp.bad_request("invalid id")
  }
}

fn new_message_decoder() -> decode.Decoder(#(String, String)) {
  use sender <- decode.field("sender", decode.string)
  use body <- decode.field("body", decode.string)
  decode.success(#(sender, body))
}

fn add_cors(resp: Response) -> Response {
  resp
  |> response.set_header("access-control-allow-origin", "*")
  |> response.set_header(
    "access-control-allow-methods",
    "GET, POST, DELETE, OPTIONS",
  )
  |> response.set_header("access-control-allow-headers", "content-type")
  |> response.set_header("access-control-max-age", "86400")
}
