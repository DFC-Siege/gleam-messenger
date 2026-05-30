import gleam/dynamic/decode
import gleam/json.{type Json}

pub type Message {
  Message(id: Int, sender: String, body: String)
}

pub fn to_json(message: Message) -> Json {
  json.object([
    #("id", json.int(message.id)),
    #("sender", json.string(message.sender)),
    #("body", json.string(message.body)),
  ])
}

pub fn decoder() -> decode.Decoder(Message) {
  use id <- decode.field("id", decode.int)
  use sender <- decode.field("sender", decode.string)
  use body <- decode.field("body", decode.string)
  decode.success(Message(id:, sender:, body:))
}
