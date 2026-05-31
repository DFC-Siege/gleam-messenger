import gleam/dynamic/decode
import gleam/result
import pog
import shared/message.{type Message, Message}

pub fn all(db: pog.Connection) -> List(Message) {
  let assert Ok(returned) =
    pog.query(
      "select m.id, m.user_id, u.username, m.body
       from messages m join users u on u.id = m.user_id
       order by m.id",
    )
    |> pog.returning(decoder())
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
    |> pog.returning(decoder())
    |> pog.execute(db)
  let assert [message] = returned.rows
  message
}

pub fn author(db: pog.Connection, id: Int) -> Result(Int, Nil) {
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

fn decoder() -> decode.Decoder(Message) {
  use id <- decode.field(0, decode.int)
  use user_id <- decode.field(1, decode.int)
  use sender <- decode.field(2, decode.string)
  use body <- decode.field(3, decode.string)
  decode.success(Message(id:, user_id:, sender:, body:))
}
