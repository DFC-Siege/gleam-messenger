import server/chat/message.{type Message}

/// Events broadcast through the hub to every connected server component. Lustre
/// ships the resulting DOM patches to clients, so there is no wire format here.
pub type Event {
  MessageCreated(message: Message)
  MessageDeleted(id: Int)
}
