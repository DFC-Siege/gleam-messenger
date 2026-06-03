import shared/message.{type Message}

/// Events broadcast through the server-side hub to every connected server
/// component. Lustre ships the resulting DOM patches to clients, so there is
/// no manual JSON transport for these anymore.
pub type Event {
  MessageCreated(message: Message)
  MessageDeleted(id: Int)
}
