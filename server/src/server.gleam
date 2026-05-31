import gleam/erlang/process
import gleam/http/request
import gleam/otp/static_supervisor as supervisor
import mist
import pog
import server/context.{Context}
import server/db
import server/hub
import server/router
import server/socket
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let db_name = process.new_name("messenger_db")
  let hub_name = process.new_name("messenger_hub")

  let conn = pog.named_connection(db_name)
  let broadcaster = process.named_subject(hub_name)
  let ctx = Context(db: conn, hub: broadcaster)

  let wisp_handler =
    wisp_mist.handler(
      fn(req) { router.handle_request(ctx, req) },
      secret_key_base,
    )

  let handler = fn(req) {
    case request.path_segments(req) {
      ["ws"] -> socket.handle(req, conn, broadcaster)
      _ -> wisp_handler(req)
    }
  }

  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(pog.supervised(db.config(db_name)))
    |> supervisor.add(hub.supervised(hub_name))
    |> supervisor.add(
      handler
      |> mist.new
      |> mist.port(8000)
      |> mist.bind("0.0.0.0")
      |> mist.supervised,
    )
    |> supervisor.start

  process.sleep_forever()
}
