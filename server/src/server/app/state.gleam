import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import server/context.{type Context}
import shared/event.{type Event}
import shared/message.{type Message}
import shared/user.{type User}

/// Arguments handed to the server component when it boots for a connection.
/// `session` is `Some` when the connection arrived with a valid token.
pub type Flags {
  Flags(ctx: Context, session: Option(Session))
}

pub type Session {
  Session(token: String, user: User)
}

/// Which screen the component is currently showing.
pub type View {
  Login
  Register
  Chat
}

pub type Model {
  Model(
    ctx: Context,
    view: View,
    session: Option(Session),
    username: String,
    password: String,
    auth_error: Option(String),
    messages: List(Message),
    draft: String,
    chat_error: Option(String),
    // Subject registered with the hub so we can unsubscribe on logout.
    hub_subject: Option(Subject(Event)),
  )
}

pub type Msg {
  // Auth
  UpdatedUsername(String)
  UpdatedPassword(String)
  SubmittedLogin
  SubmittedRegister
  ShowLogin
  ShowRegister
  ClickedLogout
  // Chat
  UpdatedDraft(String)
  SubmittedDraft
  ClickedDelete(Int)
  // Realtime
  GotHubSubject(Subject(Event))
  ServerPushed(Event)
}
