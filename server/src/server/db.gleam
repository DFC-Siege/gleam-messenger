import gleam/dynamic/decode
import gleam/erlang/process.{type Name}
import gleam/option.{Some}
import gleam/result
import pog
import shared/message.{type Message, Message}
import shared/user.{type User, User}

pub fn config(name: Name(pog.Message)) -> pog.Config {
  pog.default_config(pool_name: name)
  |> pog.host("localhost")
  |> pog.port(5433)
  |> pog.database("messenger")
  |> pog.user("messenger")
  |> pog.password(Some("messenger"))
}

// --- users ---

pub fn create_user(
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
  |> pog.returning(user_decoder())
  |> pog.execute(db)
  |> result.replace_error(Nil)
  |> result.try(fn(returned) {
    case returned.rows {
      [user] -> Ok(user)
      _ -> Error(Nil)
    }
  })
}

pub fn find_user_by_username(
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

// --- sessions ---

pub fn create_session(db: pog.Connection, user_id: Int, token: String) -> Nil {
  let assert Ok(_) =
    pog.query("insert into sessions (token, user_id) values ($1, $2)")
    |> pog.parameter(pog.text(token))
    |> pog.parameter(pog.int(user_id))
    |> pog.execute(db)
  Nil
}

pub fn find_user_by_token(
  db: pog.Connection,
  token: String,
) -> Result(User, Nil) {
  pog.query(
    "select u.id, u.username from users u
     join sessions s on s.user_id = u.id
     where s.token = $1",
  )
  |> pog.parameter(pog.text(token))
  |> pog.returning(user_decoder())
  |> pog.execute(db)
  |> result.replace_error(Nil)
  |> result.try(fn(returned) {
    case returned.rows {
      [user] -> Ok(user)
      _ -> Error(Nil)
    }
  })
}

pub fn delete_session(db: pog.Connection, token: String) -> Nil {
  let assert Ok(_) =
    pog.query("delete from sessions where token = $1")
    |> pog.parameter(pog.text(token))
    |> pog.execute(db)
  Nil
}

// --- messages ---

pub fn all(db: pog.Connection) -> List(Message) {
  let assert Ok(returned) =
    pog.query(
      "select m.id, m.user_id, u.username, m.body
       from messages m join users u on u.id = m.user_id
       order by m.id",
    )
    |> pog.returning(message_decoder())
    |> pog.execute(db)
  returned.rows
}

pub fn insert(db: pog.Connection, user_id: Int, body: String) -> Message {
  let assert Ok(returned) =
    pog.query(
      "with inserted as (
         insert into messages (user_id, body) values ($1, $2)
         returning id, user_id, body
       )
       select i.id, i.user_id, u.username, i.body
       from inserted i join users u on u.id = i.user_id",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text(body))
    |> pog.returning(message_decoder())
    |> pog.execute(db)
  let assert [message] = returned.rows
  message
}

pub fn message_author(db: pog.Connection, id: Int) -> Result(Int, Nil) {
  let decoder = decode.at([0], decode.int)

  pog.query("select user_id from messages where id = $1")
  |> pog.parameter(pog.int(id))
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.replace_error(Nil)
  |> result.try(fn(returned) {
    case returned.rows {
      [user_id] -> Ok(user_id)
      _ -> Error(Nil)
    }
  })
}

pub fn delete(db: pog.Connection, id: Int) -> Nil {
  let assert Ok(_) =
    pog.query("delete from messages where id = $1")
    |> pog.parameter(pog.int(id))
    |> pog.execute(db)
  Nil
}

fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field(0, decode.int)
  use username <- decode.field(1, decode.string)
  decode.success(User(id:, username:))
}

fn message_decoder() -> decode.Decoder(Message) {
  use id <- decode.field(0, decode.int)
  use user_id <- decode.field(1, decode.int)
  use sender <- decode.field(2, decode.string)
  use body <- decode.field(3, decode.string)
  decode.success(Message(id:, user_id:, sender:, body:))
}
