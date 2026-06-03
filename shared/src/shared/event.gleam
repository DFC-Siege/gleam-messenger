import gleam/dynamic/decode
import gleam/json.{type Json}
import shared/message.{type Message}

pub type Event {
  MessageCreated(message: Message)
  MessageDeleted(id: Int)
}

pub fn to_json(event: Event) -> Json {
  case event {
    MessageCreated(message) ->
      json.object([
        #("type", json.string("message_created")),
        #("message", message.to_json(message)),
      ])
    MessageDeleted(id) ->
      json.object([
        #("type", json.string("message_deleted")),
        #("id", json.int(id)),
      ])
  }
}

pub fn decoder() -> decode.Decoder(Event) {
  use tag <- decode.field("type", decode.string)
  case tag {
    "message_created" -> {
      use message <- decode.field("message", message.decoder())
      decode.success(MessageCreated(message))
    }
    "message_deleted" -> {
      use id <- decode.field("id", decode.int)
      decode.success(MessageDeleted(id))
    }
    _ -> decode.failure(MessageDeleted(0), "Event")
  }
}
