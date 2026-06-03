import pog
import server/auth/user.{type User, User}
import server/shared/db/sql

pub fn create(db: pog.Connection, user_id: Int, token: String) -> Nil {
  let assert Ok(_) = sql.create_session(db, token, user_id)
  Nil
}

pub fn delete(db: pog.Connection, token: String) -> Nil {
  let assert Ok(_) = sql.delete_session(db, token)
  Nil
}

pub fn find_user_by_token(
  db: pog.Connection,
  token: String,
) -> Result(User, Nil) {
  case sql.find_user_by_token(db, token) {
    Ok(pog.Returned(rows: [row], ..)) ->
      Ok(User(id: row.id, username: row.username))
    _ -> Error(Nil)
  }
}
