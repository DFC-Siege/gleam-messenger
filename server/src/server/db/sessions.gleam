import gleam/result
import pog
import server/db/users
import shared/user.{type User}

pub fn create(db: pog.Connection, user_id: Int, token: String) -> Nil {
  let assert Ok(_) =
    pog.query("insert into sessions (token, user_id) values ($1, $2)")
    |> pog.parameter(pog.text(token))
    |> pog.parameter(pog.int(user_id))
    |> pog.execute(db)
  Nil
}

pub fn delete(db: pog.Connection, token: String) -> Nil {
  let assert Ok(_) =
    pog.query("delete from sessions where token = $1")
    |> pog.parameter(pog.text(token))
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
  |> pog.returning(users.decoder())
  |> pog.execute(db)
  |> result.replace_error(Nil)
  |> result.try(fn(returned) {
    case returned.rows {
      [user] -> Ok(user)
      _ -> Error(Nil)
    }
  })
}
