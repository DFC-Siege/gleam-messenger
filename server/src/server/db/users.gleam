import pog
import server/db/sql
import shared/user.{type User, User}

pub fn create(
  db: pog.Connection,
  username: String,
  password_hash: String,
) -> Result(User, Nil) {
  case sql.create_user(db, username, password_hash) {
    Ok(pog.Returned(rows: [row], ..)) ->
      Ok(User(id: row.id, username: row.username))
    _ -> Error(Nil)
  }
}

pub fn find_by_username(
  db: pog.Connection,
  username: String,
) -> Result(#(User, String), Nil) {
  case sql.find_user_by_username(db, username) {
    Ok(pog.Returned(rows: [row], ..)) ->
      Ok(#(User(id: row.id, username: row.username), row.password_hash))
    _ -> Error(Nil)
  }
}
