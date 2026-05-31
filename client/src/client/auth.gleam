import client/api
import client/auth/token
import client/env
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/effect.{type Effect}
import rsvp
import shared/credentials
import shared/user.{type User}

const base_url = env.api_base

const me_url = base_url <> "me"

const register_url = base_url <> "register"

const login_url = base_url <> "login"

const session_url = base_url <> "session"

pub type Session {
  Session(token: String, user: User)
}

pub type Model {
  Model(username_input: String, password_input: String, error: Option(String))
}

pub type Msg {
  UpdatedUsername(String)
  UpdatedPassword(String)
  SubmittedLogin
  SubmittedRegister
  GotAuth(Result(Session, rsvp.Error))
  Restored(Result(User, rsvp.Error))
  Rechecked(Result(User, rsvp.Error))
  LoggedOut(Result(Nil, rsvp.Error))
}

pub type Out {
  Nothing
  Authenticated(Session)
  SessionExpired
}

pub fn init() -> Model {
  Model(username_input: "", password_input: "", error: None)
}

pub fn restore() -> Effect(Msg) {
  case token.get_token() {
    "" -> effect.none()
    t -> api.get(me_url, t, rsvp.expect_json(user.decoder(), Restored))
  }
}

pub fn recheck() -> Effect(Msg) {
  api.get(
    me_url,
    token.get_token(),
    rsvp.expect_json(user.decoder(), Rechecked),
  )
}

pub fn logout(session_token: String) -> Effect(Msg) {
  api.delete(
    session_url,
    session_token,
    rsvp.expect_ok_response(fn(res) {
      case res {
        Ok(_) -> LoggedOut(Ok(Nil))
        Error(err) -> LoggedOut(Error(err))
      }
    }),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg), Out) {
  case msg {
    UpdatedUsername(value) -> #(
      Model(..model, username_input: value),
      effect.none(),
      Nothing,
    )

    UpdatedPassword(value) -> #(
      Model(..model, password_input: value),
      effect.none(),
      Nothing,
    )

    SubmittedRegister ->
      case credentials.validate(model.username_input, model.password_input) {
        Error(errors) -> #(
          Model(..model, error: Some(error_message(errors))),
          effect.none(),
          Nothing,
        )
        Ok(_) -> #(model, authenticate(register_url, model), Nothing)
      }

    SubmittedLogin -> #(model, authenticate(login_url, model), Nothing)

    GotAuth(Ok(session)) -> #(
      Model(..model, password_input: "", error: None),
      token.store_token(session.token),
      Authenticated(session),
    )

    GotAuth(Error(_)) -> #(
      Model(..model, error: Some("That didn't work — check your details")),
      effect.none(),
      Nothing,
    )

    Restored(Ok(user)) -> #(
      model,
      effect.none(),
      Authenticated(Session(token: token.get_token(), user:)),
    )

    Restored(Error(_)) -> #(model, token.forget_token(), Nothing)

    Rechecked(Error(rsvp.HttpError(response))) if response.status == 401 -> #(
      Model(..model, error: Some("Session expired — please log in again")),
      token.forget_token(),
      SessionExpired,
    )

    Rechecked(_) -> #(model, effect.none(), Nothing)

    LoggedOut(_) -> #(model, effect.none(), Nothing)
  }
}

fn error_message(errors: List(credentials.Error)) -> String {
  errors
  |> list.map(credentials.message)
  |> string.join(". ")
}

fn authenticate(url: String, model: Model) -> Effect(Msg) {
  let body =
    json.object([
      #("username", json.string(model.username_input)),
      #("password", json.string(model.password_input)),
    ])
  rsvp.post(url, body, rsvp.expect_json(session_decoder(), GotAuth))
}

fn session_decoder() -> decode.Decoder(Session) {
  use token <- decode.field("token", decode.string)
  use user <- decode.field("user", user.decoder())
  decode.success(Session(token:, user:))
}
