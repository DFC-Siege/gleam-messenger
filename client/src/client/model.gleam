import client/api
import client/auth
import client/router.{type Route, Chat, Login}
import client/socket
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/effect.{type Effect}
import modem
import rsvp
import shared/event.{Created, Deleted}
import shared/message.{type Message}
import shared/user.{type User}

const me_url = "http://localhost:8000/api/me"

const messages_url = "http://localhost:8000/api/messages"

const register_url = "http://localhost:8000/api/register"

const login_url = "http://localhost:8000/api/login"

const session_url = "http://localhost:8000/api/session"

const ws_base = "ws://localhost:8000/ws?token="

pub type Session {
  Session(token: String, user: User)
}

pub type Model {
  Model(
    route: Route,
    session: Option(Session),
    username_input: String,
    password_input: String,
    auth_error: Option(String),
    messages: List(Message),
    draft: String,
    error: Option(String),
  )
}

pub type Msg {
  OnRouteChange(Route)
  UpdatedUsername(String)
  UpdatedPassword(String)
  SubmittedRegister
  SubmittedLogin
  ClickedLogout
  ApiAuthed(Result(Session, rsvp.Error))
  ApiGotMe(Result(User, rsvp.Error))
  ApiLoggedOut(Result(Nil, rsvp.Error))
  ApiReturnedMessages(Result(List(Message), rsvp.Error))
  ApiCreatedMessage(Result(Message, rsvp.Error))
  ApiDeletedMessage(Result(Nil, rsvp.Error))
  ServerPushedEvent(String)
  UpdatedDraft(String)
  SubmittedDraft
  ClickedDelete(Int)
}

pub fn init(_flags) -> #(Model, Effect(Msg)) {
  let route = case modem.initial_uri() {
    Ok(uri) -> router.from_uri(uri)
    Error(_) -> Login
  }

  let restore = case auth.get_token() {
    "" -> effect.none()
    token -> api.get(me_url, token, rsvp.expect_json(user.decoder(), ApiGotMe))
  }

  let model =
    Model(
      route:,
      session: None,
      username_input: "",
      password_input: "",
      auth_error: None,
      messages: [],
      draft: "",
      error: None,
    )

  #(
    model,
    effect.batch([
      modem.init(fn(uri) { OnRouteChange(router.from_uri(uri)) }),
      restore,
    ]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(route) -> #(Model(..model, route:), effect.none())

    UpdatedUsername(value) -> #(
      Model(..model, username_input: value),
      effect.none(),
    )

    UpdatedPassword(value) -> #(
      Model(..model, password_input: value),
      effect.none(),
    )

    SubmittedRegister -> #(model, authenticate(register_url, model))

    SubmittedLogin -> #(model, authenticate(login_url, model))

    ApiAuthed(Ok(session)) -> #(
      Model(..model, session: Some(session), password_input: "", auth_error: None),
      effect.batch([
        auth.store_token(session.token),
        modem.push(router.to_path(Chat), None, None),
        enter_chat(session.token),
      ]),
    )

    ApiAuthed(Error(_)) -> #(
      Model(..model, auth_error: Some("That didn't work — check your details")),
      effect.none(),
    )

    ApiGotMe(Ok(user)) -> {
      let token = auth.get_token()
      #(Model(..model, session: Some(Session(token:, user:))), enter_chat(token))
    }

    ApiGotMe(Error(_)) -> #(Model(..model, session: None), auth.forget_token())

    ClickedLogout -> #(
      Model(..model, session: None, messages: [], draft: ""),
      effect.batch([
        api.delete(session_url, token(model), rsvp.expect_ok_response(to_logged_out)),
        auth.forget_token(),
        modem.push(router.to_path(Login), None, None),
      ]),
    )

    ApiLoggedOut(_) -> #(model, effect.none())

    ApiReturnedMessages(Ok(messages)) -> #(
      Model(..model, messages:, error: None),
      effect.none(),
    )

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

    UpdatedDraft(draft) -> #(Model(..model, draft:), effect.none())

    SubmittedDraft ->
      case string.trim(model.draft) {
        "" -> #(model, effect.none())
        body -> #(model, send_message(token(model), body))
      }

    ClickedDelete(id) -> #(model, delete_message(token(model), id))
  }
}

fn token(model: Model) -> String {
  case model.session {
    Some(session) -> session.token
    None -> ""
  }
}

fn authenticate(url: String, model: Model) -> Effect(Msg) {
  let body =
    json.object([
      #("username", json.string(model.username_input)),
      #("password", json.string(model.password_input)),
    ])
  rsvp.post(url, body, rsvp.expect_json(session_decoder(), ApiAuthed))
}

fn enter_chat(token: String) -> Effect(Msg) {
  effect.batch([
    api.get(
      messages_url,
      token,
      rsvp.expect_json(decode.list(message.decoder()), ApiReturnedMessages),
    ),
    socket.listen(ws_base <> token, ServerPushedEvent),
  ])
}

fn send_message(token: String, body: String) -> Effect(Msg) {
  api.post(
    messages_url,
    token,
    json.object([#("body", json.string(body))]),
    rsvp.expect_json(message.decoder(), ApiCreatedMessage),
  )
}

fn delete_message(token: String, id: Int) -> Effect(Msg) {
  api.delete(
    messages_url <> "/" <> int.to_string(id),
    token,
    rsvp.expect_ok_response(fn(res) {
      case res {
        Ok(_) -> ApiDeletedMessage(Ok(Nil))
        Error(err) -> ApiDeletedMessage(Error(err))
      }
    }),
  )
}

fn to_logged_out(res) -> Msg {
  case res {
    Ok(_) -> ApiLoggedOut(Ok(Nil))
    Error(err) -> ApiLoggedOut(Error(err))
  }
}

fn session_decoder() -> decode.Decoder(Session) {
  use token <- decode.field("token", decode.string)
  use user <- decode.field("user", user.decoder())
  decode.success(Session(token:, user:))
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
