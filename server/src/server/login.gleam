import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/effect.{type Effect}
import lustre/server_component
import server/auth
import server/context.{type Context}
import server/credentials
import server/db/sessions
import server/db/users
import server/session.{type Session, Session}
import server/user.{type User}

pub type Model {
  Model(
    username: String,
    password: String,
    registering: Bool,
    error: Option(String),
  )
}

pub type Msg {
  UpdatedUsername(String)
  UpdatedPassword(String)
  SubmittedLogin
  SubmittedRegister
  ShowLogin
  ShowRegister
}

/// What the parent needs to know after handling a message.
pub type Out {
  Nothing
  Authenticated(Session)
}

pub fn init() -> Model {
  Model(username: "", password: "", registering: False, error: None)
}

pub fn update(
  ctx: Context,
  model: Model,
  msg: Msg,
) -> #(Model, Effect(Msg), Out) {
  case msg {
    UpdatedUsername(value) -> #(
      Model(..model, username: value),
      effect.none(),
      Nothing,
    )

    UpdatedPassword(value) -> #(
      Model(..model, password: value),
      effect.none(),
      Nothing,
    )

    ShowLogin -> #(
      Model(..model, registering: False, error: None),
      effect.none(),
      Nothing,
    )

    ShowRegister -> #(
      Model(..model, registering: True, error: None),
      effect.none(),
      Nothing,
    )

    SubmittedLogin -> attempt_login(ctx, model)

    SubmittedRegister -> attempt_register(ctx, model)
  }
}

fn attempt_register(ctx: Context, model: Model) -> #(Model, Effect(Msg), Out) {
  case credentials.validate(model.username, model.password) {
    Error(errors) -> rejected(model, error_message(errors))
    Ok(_) ->
      case
        users.create(ctx.db, model.username, auth.hash_password(model.password))
      {
        Ok(user) -> succeed(ctx, user)
        Error(_) -> rejected(model, "That username is taken")
      }
  }
}

fn attempt_login(ctx: Context, model: Model) -> #(Model, Effect(Msg), Out) {
  case users.find_by_username(ctx.db, model.username) {
    Ok(#(user, hash)) ->
      case auth.verify_password(model.password, hash) {
        True -> succeed(ctx, user)
        False -> rejected(model, "That didn't work — check your details")
      }
    Error(_) -> rejected(model, "That didn't work — check your details")
  }
}

// Mint a session, persist it, and hand the token back to the browser so it
// survives reloads (the page shim stores it and feeds it into the connect URL).
fn succeed(ctx: Context, user: User) -> #(Model, Effect(Msg), Out) {
  let token = auth.generate_token()
  sessions.create(ctx.db, user.id, token)
  #(
    init(),
    server_component.emit("auth", json.string(token)),
    Authenticated(Session(token:, user:)),
  )
}

fn rejected(model: Model, reason: String) -> #(Model, Effect(Msg), Out) {
  #(Model(..model, error: Some(reason)), effect.none(), Nothing)
}

fn error_message(errors: List(credentials.Error)) -> String {
  errors
  |> list.map(credentials.message)
  |> string.join(". ")
}
