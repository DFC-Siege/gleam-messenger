import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/result
import mist.{type Connection, type ResponseData}
import pog
import server/db
import server/hub.{type Hub}
import shared/event

pub fn handle(
  req: Request(Connection),
  database: pog.Connection,
  hub: Hub,
) -> Response(ResponseData) {
  case authorized(req, database) {
    True ->
      mist.websocket(
        request: req,
        on_init: fn(_conn) {
          let client = process.new_subject()
          hub.subscribe(hub, client)
          let selector = process.new_selector() |> process.select(client)
          #(client, Some(selector))
        },
        on_close: fn(client) { hub.unsubscribe(hub, client) },
        handler: fn(client, ws_message, conn) {
          case ws_message {
            mist.Custom(evt) -> {
              let _ =
                mist.send_text_frame(conn, json.to_string(event.to_json(evt)))
              mist.continue(client)
            }
            mist.Closed | mist.Shutdown -> mist.stop()
            _ -> mist.continue(client)
          }
        },
      )
    False -> response.new(401) |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}

fn authorized(req: Request(Connection), database: pog.Connection) -> Bool {
  case token(req) {
    Ok(t) -> result.is_ok(db.find_user_by_token(database, t))
    Error(_) -> False
  }
}

fn token(req: Request(Connection)) -> Result(String, Nil) {
  use params <- result.try(request.get_query(req))
  list.key_find(params, "token")
}
