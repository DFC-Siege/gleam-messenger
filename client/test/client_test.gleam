import client/auth
import client/chat
import gleam/json
import gleam/option.{None}
import gleeunit
import shared/event
import shared/message.{Message}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn auth_updated_username_test() {
  let #(model, _effect, out) =
    auth.update(auth.init(), auth.UpdatedUsername("joe"))

  assert model.username_input == "joe"
  assert out == auth.Nothing
}

pub fn chat_empty_draft_is_noop_test() {
  let model = chat.Model(token: "t", messages: [], draft: "   ", error: None)
  let #(updated, _effect, out) = chat.update(model, chat.SubmittedDraft)

  assert updated == model
  assert out == chat.Nothing
}

pub fn chat_server_push_adds_message_test() {
  let incoming = Message(id: 1, user_id: 1, sender: "joe", body: "hi")
  let raw = json.to_string(event.to_json(event.Created(incoming)))

  let #(model, _effect, out) = chat.update(chat.init(), chat.ServerPushed(raw))

  assert model.messages == [incoming]
  assert out == chat.Nothing
}

pub fn chat_server_push_removes_message_test() {
  let existing = Message(id: 1, user_id: 1, sender: "joe", body: "hi")
  let start = chat.Model(..chat.init(), messages: [existing])
  let raw = json.to_string(event.to_json(event.Deleted(1)))

  let #(model, _effect, out) = chat.update(start, chat.ServerPushed(raw))

  assert model.messages == []
  assert out == chat.Nothing
}

pub fn chat_logout_requests_logout_test() {
  let #(_model, _effect, out) = chat.update(chat.init(), chat.ClickedLogout)

  assert out == chat.RequestLogout
}

pub fn chat_socket_give_up_signals_connection_lost_test() {
  let #(_model, _effect, out) = chat.update(chat.init(), chat.SocketGaveUp)

  assert out == chat.ConnectionLost
}
