import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/effect.{type Effect}
import lustre/server_component
import server/auth/session.{type Session}
import server/chat/event.{type Event, MessageCreated, MessageDeleted}
import server/chat/message.{type Message}
import server/chat/queries as messages
import server/shared/context.{type Context}
import server/shared/hub

pub type Model {
  Model(
    messages: List(Message),
    draft: String,
    error: Option(String),
    // Subject registered with the hub, kept so we can unsubscribe on logout.
    hub_subject: Option(Subject(Event)),
  )
}

pub type Msg {
  UpdatedDraft(String)
  SubmittedDraft
  ClickedDelete(Int)
  ClickedLogout
  GotHubSubject(Subject(Event))
  ServerPushed(Event)
}

/// What the parent needs to know after handling a message.
pub type Out {
  Nothing
  RequestLogout
}

pub fn init() -> Model {
  Model(messages: [], draft: "", error: None, hub_subject: None)
}

// Load history and subscribe to the hub for realtime updates. Lustre ships the
// resulting DOM patches to the client.
pub fn enter(ctx: Context) -> #(Model, Effect(Msg)) {
  #(Model(..init(), messages: messages.all(ctx.db)), subscribe(ctx.hub))
}

fn subscribe(h: hub.Hub) -> Effect(Msg) {
  use dispatch, subject <- server_component.select
  hub.subscribe(h, subject)
  // Stash the subject in the model so we can unsubscribe on logout.
  dispatch(GotHubSubject(subject))
  process.new_selector()
  |> process.select_map(subject, ServerPushed)
}

pub fn update(
  ctx: Context,
  session: Session,
  model: Model,
  msg: Msg,
) -> #(Model, Effect(Msg), Out) {
  case msg {
    UpdatedDraft(value) -> #(
      Model(..model, draft: value),
      effect.none(),
      Nothing,
    )

    SubmittedDraft ->
      case string.trim(model.draft) {
        "" -> #(model, effect.none(), Nothing)
        body -> {
          let created = messages.insert(ctx.db, session.user.id, body)
          hub.publish(ctx.hub, MessageCreated(created))
          #(Model(..model, draft: ""), effect.none(), Nothing)
        }
      }

    ClickedDelete(id) -> {
      case messages.author(ctx.db, id) {
        Ok(author_id) if author_id == session.user.id -> {
          messages.delete(ctx.db, id)
          hub.publish(ctx.hub, MessageDeleted(id))
        }
        _ -> Nil
      }
      #(model, effect.none(), Nothing)
    }

    ClickedLogout -> {
      case model.hub_subject {
        Some(subject) -> hub.unsubscribe(ctx.hub, subject)
        None -> Nil
      }
      #(init(), effect.none(), RequestLogout)
    }

    GotHubSubject(subject) -> #(
      Model(..model, hub_subject: Some(subject)),
      effect.none(),
      Nothing,
    )

    ServerPushed(MessageCreated(message)) -> #(
      Model(..model, messages: upsert(model.messages, message)),
      effect.none(),
      Nothing,
    )

    ServerPushed(MessageDeleted(id)) -> #(
      Model(..model, messages: remove(model.messages, id)),
      effect.none(),
      Nothing,
    )
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
