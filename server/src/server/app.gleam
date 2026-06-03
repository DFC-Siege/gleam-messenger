import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/server_component
import server/app/state.{
  type Flags, type Model, type Msg, type Session, Chat, ClickedDelete,
  ClickedLogout, GotHubSubject, Login, Model, Register, ServerPushed, Session,
  ShowLogin, ShowRegister, SubmittedDraft, SubmittedLogin, SubmittedRegister,
  UpdatedDraft, UpdatedPassword, UpdatedUsername,
}
import server/auth
import server/db/messages
import server/db/sessions
import server/db/users
import server/hub
import server/views/auth as auth_view
import server/views/chat as chat_view
import shared/credentials
import shared/event.{MessageCreated, MessageDeleted}
import shared/message.{type Message}
import shared/user.{type User}

pub fn app() -> lustre.App(Flags, Model, Msg) {
  lustre.application(init, update, view)
}

fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ctx: flags.ctx,
      view: Login,
      session: None,
      username: "",
      password: "",
      auth_error: None,
      messages: [],
      draft: "",
      chat_error: None,
      hub_subject: None,
    )

  case flags.session {
    Some(session) -> enter_chat(model, session)
    None -> #(model, effect.none())
  }
}

// Transition into the chat view: load history and subscribe to the hub for
// realtime updates. Lustre ships the resulting DOM patches to the client.
fn enter_chat(model: Model, session: Session) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      view: Chat,
      session: Some(session),
      messages: messages.all(model.ctx.db),
      auth_error: None,
      password: "",
    ),
    subscribe_to_hub(model.ctx.hub),
  )
}

fn subscribe_to_hub(h: hub.Hub) -> Effect(Msg) {
  use dispatch, subject <- server_component.select
  hub.subscribe(h, subject)
  // Stash the subject in the model so we can unsubscribe on logout.
  dispatch(GotHubSubject(subject))
  process.new_selector()
  |> process.select_map(subject, ServerPushed)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UpdatedUsername(value) -> #(Model(..model, username: value), effect.none())

    UpdatedPassword(value) -> #(Model(..model, password: value), effect.none())

    UpdatedDraft(value) -> #(Model(..model, draft: value), effect.none())

    ShowLogin -> #(Model(..model, view: Login, auth_error: None), effect.none())

    ShowRegister -> #(
      Model(..model, view: Register, auth_error: None),
      effect.none(),
    )

    SubmittedRegister ->
      case credentials.validate(model.username, model.password) {
        Error(errors) -> #(
          Model(..model, auth_error: Some(error_message(errors))),
          effect.none(),
        )
        Ok(_) ->
          case
            users.create(
              model.ctx.db,
              model.username,
              auth.hash_password(model.password),
            )
          {
            Ok(user) -> login_success(model, user)
            Error(_) -> #(
              Model(..model, auth_error: Some("That username is taken")),
              effect.none(),
            )
          }
      }

    SubmittedLogin ->
      case users.find_by_username(model.ctx.db, model.username) {
        Ok(#(user, hash)) ->
          case auth.verify_password(model.password, hash) {
            True -> login_success(model, user)
            False -> bad_credentials(model)
          }
        Error(_) -> bad_credentials(model)
      }

    ClickedLogout -> {
      case model.session {
        Some(session) -> sessions.delete(model.ctx.db, session.token)
        None -> Nil
      }
      case model.hub_subject {
        Some(subject) -> hub.unsubscribe(model.ctx.hub, subject)
        None -> Nil
      }
      #(
        Model(
          ..model,
          view: Login,
          session: None,
          messages: [],
          draft: "",
          password: "",
          hub_subject: None,
        ),
        server_component.emit("logout", json.null()),
      )
    }

    SubmittedDraft ->
      case model.session {
        Some(session) ->
          case string.trim(model.draft) {
            "" -> #(model, effect.none())
            body -> {
              let created = messages.insert(model.ctx.db, session.user.id, body)
              hub.publish(model.ctx.hub, MessageCreated(created))
              #(Model(..model, draft: ""), effect.none())
            }
          }
        None -> #(model, effect.none())
      }

    ClickedDelete(id) ->
      case model.session {
        Some(session) ->
          case messages.author(model.ctx.db, id) {
            Ok(author_id) if author_id == session.user.id -> {
              messages.delete(model.ctx.db, id)
              hub.publish(model.ctx.hub, MessageDeleted(id))
              #(model, effect.none())
            }
            _ -> #(model, effect.none())
          }
        None -> #(model, effect.none())
      }

    GotHubSubject(subject) -> #(
      Model(..model, hub_subject: Some(subject)),
      effect.none(),
    )

    ServerPushed(MessageCreated(message)) -> #(
      Model(..model, messages: upsert(model.messages, message)),
      effect.none(),
    )

    ServerPushed(MessageDeleted(id)) -> #(
      Model(..model, messages: remove(model.messages, id)),
      effect.none(),
    )
  }
}

// Mint a session, persist it, enter chat and hand the token back to the
// browser so it survives reloads (the page shim stores it and feeds it into
// the server component's connect URL).
fn login_success(model: Model, user: User) -> #(Model, Effect(Msg)) {
  let token = auth.generate_token()
  sessions.create(model.ctx.db, user.id, token)
  let #(model, hub_eff) = enter_chat(model, Session(token:, user:))
  #(
    model,
    effect.batch([hub_eff, server_component.emit("auth", json.string(token))]),
  )
}

fn bad_credentials(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, auth_error: Some("That didn't work — check your details")),
    effect.none(),
  )
}

fn view(model: Model) -> Element(Msg) {
  case model.view, model.session {
    Chat, Some(session) -> chat_view.view(model, session.user)
    _, _ -> auth_view.view(model)
  }
}

fn error_message(errors: List(credentials.Error)) -> String {
  errors
  |> list.map(credentials.message)
  |> string.join(". ")
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
