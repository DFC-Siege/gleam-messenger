import gleam/dynamic/decode
import gleam/result
import pog
import shared/user.{type User, User}

pub fn decoder() -> decode.Decoder(User) {
  use id <- decode.field(0, decode.int)
  use username <- decode.field(1, decode.string)
  decode.success(User(id:, username:))
}

pub fn create(
  db: pog.Connection,
  username: String,
  password_hash: String,
) -> Result(User, Nil) {
  pog.query(
    "insert into users (username, password_hash) values ($1, $2)
     returning id, username",
  )
  |> pog.parameter(pog.text(username))
  |> pog.parameter(pog.text(password_hash))
  |> pog.returning(decoder())
  |> pog.execute(db)
  |> result.replace_error(Nil)
  |> result.try(fn(returned) {
    case returned.rows {
      [user] -> Ok(user)
      _ -> Error(Nil)
    }
  })
}

pub fn find_by_username(
  db: pog.Connection,
  username: String,
) -> Result(#(User, String), Nil) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use hash <- decode.field(2, decode.string)
    decode.success(#(User(id:, username: name), hash))
  }

  pog.query("select id, username, password_hash from users where username = $1")
  |> pog.parameter(pog.text(username))
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.replace_error(Nil)
  |> result.try(fn(returned) {
    case returned.rows {
      [row] -> Ok(row)
      _ -> Error(Nil)
    }
  })
}
