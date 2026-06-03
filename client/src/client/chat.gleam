import client/api
import client/env
import client/socket
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/effect.{type Effect}
import rsvp
import shared/event.{MessageCreated, MessageDeleted}
import shared/message.{type Message}

const base_url = env.api_base

const messages_url = base_url <> "messages"

const ws_base = env.ws_base

pub type Model {
  Model(
    token: String,
    messages: List(Message),
    draft: String,
    error: Option(String),
  )
}

pub type Msg {
  GotMessages(Result(List(Message), rsvp.Error))
  UpdatedDraft(String)
  SubmittedDraft
  SentMessage(Result(Message, rsvp.Error))
  ClickedDelete(Int)
  DeletedMessage(Result(Nil, rsvp.Error))
  ServerPushed(String)
  SocketGaveUp
  ClickedLogout
}

pub type Out {
  Nothing
  ConnectionLost
  RequestLogout
}

pub fn init() -> Model {
  Model(token: "", messages: [], draft: "", error: None)
}

pub fn enter(token: String) -> #(Model, Effect(Msg)) {
  #(
    Model(..init(), token:),
    effect.batch([
      api.get(
        messages_url,
        token,
        rsvp.expect_json(decode.list(message.decoder()), GotMessages),
      ),
      socket.listen(ws_base <> token, ServerPushed, SocketGaveUp),
    ]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg), Out) {
  case msg {
    GotMessages(Ok(messages)) -> #(
      Model(..model, messages:, error: None),
      effect.none(),
      Nothing,
    )

    UpdatedDraft(draft) -> #(Model(..model, draft:), effect.none(), Nothing)

    SubmittedDraft ->
      case string.trim(model.draft) {
        "" -> #(model, effect.none(), Nothing)
        body -> #(model, send_message(model.token, body), Nothing)
      }

    SentMessage(Ok(_)) -> #(Model(..model, draft: ""), effect.none(), Nothing)

    ClickedDelete(id) -> #(model, delete_message(model.token, id), Nothing)

    DeletedMessage(Ok(_)) -> #(model, effect.none(), Nothing)

    ServerPushed(raw) ->
      case json.parse(raw, event.decoder()) {
        Ok(MessageCreated(message)) -> #(
          Model(..model, messages: upsert(model.messages, message)),
          effect.none(),
          Nothing,
        )
        Ok(MessageDeleted(id)) -> #(
          Model(..model, messages: remove(model.messages, id)),
          effect.none(),
          Nothing,
        )
        Error(_) -> #(model, effect.none(), Nothing)
      }

    GotMessages(Error(_)) | SentMessage(Error(_)) | DeletedMessage(Error(_)) -> #(
      Model(..model, error: Some("Could not reach the server")),
      effect.none(),
      Nothing,
    )

    SocketGaveUp -> #(
      Model(..model, error: Some("Lost connection — reload to reconnect")),
      effect.none(),
      ConnectionLost,
    )

    ClickedLogout -> #(model, effect.none(), RequestLogout)
  }
}

fn send_message(token: String, body: String) -> Effect(Msg) {
  api.post(
    messages_url,
    token,
    json.object([#("body", json.string(body))]),
    rsvp.expect_json(message.decoder(), SentMessage),
  )
}

fn delete_message(token: String, id: Int) -> Effect(Msg) {
  api.delete(
    messages_url <> "/" <> int.to_string(id),
    token,
    rsvp.expect_ok_response(fn(res) {
      case res {
        Ok(_) -> DeletedMessage(Ok(Nil))
        Error(err) -> DeletedMessage(Error(err))
      }
    }),
  )
}

fn upsert(messages: List(Message), incoming: Message) -> List(Message) {
  case list.any(messages, fn(m) { m.id == incoming.id }) {
    True -> messages
    False -> list.append(messages, [incoming])
  }
}

fn remove(messages: List(Message), id: Int) -> List(Message) {
  list.filter(messages, fn(m) { m.id != id })
}
