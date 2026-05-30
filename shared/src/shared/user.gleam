import gleam/dynamic/decode
import gleam/json.{type Json}

pub type User {
  User(id: Int, username: String)
}

pub fn to_json(user: User) -> Json {
  json.object([
    #("id", json.int(user.id)),
    #("username", json.string(user.username)),
  ])
}

pub fn decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use username <- decode.field("username", decode.string)
  decode.success(User(id:, username:))
}
