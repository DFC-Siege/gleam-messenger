import gleam/dynamic/decode
import gleam/option.{Some}
import gleam/otp/actor
import gleam/result
import gleam/erlang/process
import pog
import shared/message.{type Message, Message}

pub fn connect() -> Result(pog.Connection, actor.StartError) {
  pog.default_config(pool_name: process.new_name("messenger_db"))
  |> pog.host("localhost")
  |> pog.port(5433)
  |> pog.database("messenger")
  |> pog.user("messenger")
  |> pog.password(Some("messenger"))
  |> pog.start
  |> result.map(fn(started) { started.data })
}

pub fn all(db: pog.Connection) -> List(Message) {
  let assert Ok(returned) =
    pog.query("select id, sender, body from messages order by id")
    |> pog.returning(row_decoder())
    |> pog.execute(db)
  returned.rows
}

pub fn insert(db: pog.Connection, sender: String, body: String) -> Message {
  let assert Ok(returned) =
    pog.query(
      "insert into messages (sender, body) values ($1, $2)
       returning id, sender, body",
    )
    |> pog.parameter(pog.text(sender))
    |> pog.parameter(pog.text(body))
    |> pog.returning(row_decoder())
    |> pog.execute(db)
  let assert [message] = returned.rows
  message
}

pub fn delete(db: pog.Connection, id: Int) -> Nil {
  let assert Ok(_) =
    pog.query("delete from messages where id = $1")
    |> pog.parameter(pog.int(id))
    |> pog.execute(db)
  Nil
}

fn row_decoder() -> decode.Decoder(Message) {
  use id <- decode.field(0, decode.int)
  use sender <- decode.field(1, decode.string)
  use body <- decode.field(2, decode.string)
  decode.success(Message(id:, sender:, body:))
}
