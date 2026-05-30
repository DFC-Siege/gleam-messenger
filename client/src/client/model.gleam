import client/socket
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/effect.{type Effect}
import rsvp
import shared/event.{Created, Deleted}
import shared/message.{type Message}

const api = "http://localhost:8000/api/messages"

const ws = "ws://localhost:8000/ws"

pub type Model {
  Model(messages: List(Message), draft: String, error: Option(String))
}

pub type Msg {
  ApiReturnedMessages(Result(List(Message), rsvp.Error))
  ApiCreatedMessage(Result(Message, rsvp.Error))
  ApiDeletedMessage(Result(Nil, rsvp.Error))
  ServerPushedEvent(String)
  UserUpdatedDraft(String)
  UserSubmittedDraft
  UserClickedDelete(Int)
}

pub fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(messages: [], draft: "", error: None),
    effect.batch([fetch_messages(), socket.listen(ws, ServerPushedEvent)]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ApiReturnedMessages(Ok(messages)) -> #(
      Model(..model, messages:, error: None),
      effect.none(),
    )

    // The socket echoes every change back to everyone, so the create/delete
    // requests just fire-and-forget; ServerPushedEvent updates the list.
    ApiCreatedMessage(Ok(_)) -> #(Model(..model, draft: ""), effect.none())

    ApiDeletedMessage(Ok(_)) -> #(model, effect.none())

    ServerPushedEvent(raw) ->
      case json.parse(raw, event.decoder()) {
        Ok(Created(message)) -> #(
          Model(..model, messages: upsert(model.messages, message)),
          effect.none(),
        )
        Ok(Deleted(id)) -> #(
          Model(..model, messages: remove(model.messages, id)),
          effect.none(),
        )
        Error(_) -> #(model, effect.none())
      }

    ApiReturnedMessages(Error(_))
    | ApiCreatedMessage(Error(_))
    | ApiDeletedMessage(Error(_)) -> #(
      Model(..model, error: Some("Could not reach the server")),
      effect.none(),
    )

    UserUpdatedDraft(draft) -> #(Model(..model, draft:), effect.none())

    UserSubmittedDraft ->
      case string.trim(model.draft) {
        "" -> #(model, effect.none())
        body -> #(model, send_message(body))
      }

    UserClickedDelete(id) -> #(model, delete_message(id))
  }
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

fn fetch_messages() -> Effect(Msg) {
  let decoder = decode.list(message.decoder())
  rsvp.get(api, rsvp.expect_json(decoder, ApiReturnedMessages))
}

fn send_message(body: String) -> Effect(Msg) {
  let payload =
    json.object([
      #("sender", json.string("You")),
      #("body", json.string(body)),
    ])
  rsvp.post(api, payload, rsvp.expect_json(message.decoder(), ApiCreatedMessage))
}

fn delete_message(id: Int) -> Effect(Msg) {
  rsvp.delete(
    api <> "/" <> int.to_string(id),
    json.null(),
    rsvp.expect_ok_response(fn(res) {
      case res {
        Ok(_) -> ApiDeletedMessage(Ok(Nil))
        Error(err) -> ApiDeletedMessage(Error(err))
      }
    }),
  )
}
