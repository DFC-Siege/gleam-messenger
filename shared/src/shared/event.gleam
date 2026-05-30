import gleam/dynamic/decode
import gleam/json.{type Json}
import shared/message.{type Message}

pub type Event {
  Created(message: Message)
  Deleted(id: Int)
}

pub fn to_json(event: Event) -> Json {
  case event {
    Created(message) ->
      json.object([
        #("type", json.string("created")),
        #("message", message.to_json(message)),
      ])
    Deleted(id) ->
      json.object([#("type", json.string("deleted")), #("id", json.int(id))])
  }
}

pub fn decoder() -> decode.Decoder(Event) {
  use tag <- decode.field("type", decode.string)
  case tag {
    "created" -> {
      use message <- decode.field("message", message.decoder())
      decode.success(Created(message))
    }
    "deleted" -> {
      use id <- decode.field("id", decode.int)
      decode.success(Deleted(id))
    }
    _ -> decode.failure(Deleted(0), "Event")
  }
}
