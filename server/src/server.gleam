import gleam/erlang/process
import gleam/http/request
import mist
import server/db
import server/hub
import server/router.{Context}
import server/socket
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)
  let assert Ok(db) = db.connect()
  let assert Ok(hub) = hub.start()
  let ctx = Context(db:, hub:)

  let wisp_handler =
    wisp_mist.handler(
      fn(req) { router.handle_request(ctx, req) },
      secret_key_base,
    )

  let handler = fn(req) {
    case request.path_segments(req) {
      ["ws"] -> socket.handle(req, hub)
      _ -> wisp_handler(req)
    }
  }

  let assert Ok(_) =
    handler
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}
