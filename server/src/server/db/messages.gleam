import gleam/list
import pog
import server/db/sql
import shared/message.{type Message, Message}

pub fn all(db: pog.Connection) -> List(Message) {
  let assert Ok(returned) = sql.all_messages(db)
  list.map(returned.rows, fn(row) {
    Message(
      id: row.id,
      user_id: row.user_id,
      sender: row.sender,
      body: row.body,
    )
  })
}

pub fn insert(db: pog.Connection, user_id: Int, body: String) -> Message {
  let assert Ok(pog.Returned(rows: [row], ..)) =
    sql.insert_message(db, user_id, body)
  Message(id: row.id, user_id: row.user_id, sender: row.sender, body: row.body)
}

pub fn author(db: pog.Connection, id: Int) -> Result(Int, Nil) {
  case sql.message_author(db, id) {
    Ok(pog.Returned(rows: [row], ..)) -> Ok(row.user_id)
    _ -> Error(Nil)
  }
}

pub fn delete(db: pog.Connection, id: Int) -> Nil {
  let assert Ok(_) = sql.delete_message(db, id)
  Nil
}
