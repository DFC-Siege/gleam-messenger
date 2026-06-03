import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/server_component
import mist.{type Connection, type ResponseData}
import server/app.{type Msg, Flags}
import server/context.{type Context}
import server/db/sessions
import server/session.{type Session, Session}

type State {
  State(
    runtime: lustre.Runtime(Msg),
    self: process.Subject(server_component.ClientMessage(Msg)),
  )
}

pub fn handle(
  req: Request(Connection),
  ctx: Context,
) -> Response(ResponseData) {
  mist.websocket(
    request: req,
    on_init: fn(_conn) {
      let session = restore_session(req, ctx)
      let assert Ok(runtime) =
        lustre.start_server_component(app.app(), Flags(ctx:, session:))

      let self = process.new_subject()
      process.send(
        server_component.subject(runtime),
        server_component.register_subject(self),
      )

      let selector =
        process.new_selector()
        |> process.select(self)

      #(State(runtime:, self:), Some(selector))
    },
    on_close: fn(state) {
      process.send(
        server_component.subject(state.runtime),
        server_component.deregister_subject(state.self),
      )
    },
    handler: fn(state: State, message, conn) {
      case message {
        mist.Text(text) -> {
          case json.parse(text, server_component.runtime_message_decoder()) {
            Ok(runtime_msg) ->
              process.send(server_component.subject(state.runtime), runtime_msg)
            Error(_) -> Nil
          }
          mist.continue(state)
        }

        mist.Custom(client_msg) -> {
          let payload = server_component.client_message_to_json(client_msg)
          let _ = mist.send_text_frame(conn, json.to_string(payload))
          mist.continue(state)
        }

        mist.Binary(_) -> mist.continue(state)

        mist.Closed | mist.Shutdown -> mist.stop()
      }
    },
  )
}

fn restore_session(req: Request(Connection), ctx: Context) -> Option(Session) {
  case token(req) {
    Ok(t) ->
      case sessions.find_user_by_token(ctx.db, t) {
        Ok(user) -> Some(Session(token: t, user:))
        Error(_) -> None
      }
    Error(_) -> None
  }
}

fn token(req: Request(Connection)) -> Result(String, Nil) {
  use params <- result.try(request.get_query(req))
  list.key_find(params, "token")
}
