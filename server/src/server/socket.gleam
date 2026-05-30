import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{Some}
import mist.{type Connection, type ResponseData}
import server/hub.{type Hub}
import shared/event

pub fn handle(req: Request(Connection), hub: Hub) -> Response(ResponseData) {
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
          let _ = mist.send_text_frame(conn, json.to_string(event.to_json(evt)))
          mist.continue(client)
        }
        mist.Closed | mist.Shutdown -> mist.stop()
        _ -> mist.continue(client)
      }
    },
  )
}
