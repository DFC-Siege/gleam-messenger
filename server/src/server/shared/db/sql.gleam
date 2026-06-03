//// This module contains the code to run the sql queries defined in
//// `./src/server/db/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import pog

/// A row you get from running the `all_messages` query
/// defined in `./src/server/db/sql/all_messages.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type AllMessagesRow {
  AllMessagesRow(id: Int, user_id: Int, sender: String, body: String)
}

/// Runs the `all_messages` query
/// defined in `./src/server/db/sql/all_messages.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn all_messages(
  db: pog.Connection,
) -> Result(pog.Returned(AllMessagesRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use sender <- decode.field(2, decode.string)
    use body <- decode.field(3, decode.string)
    decode.success(AllMessagesRow(id:, user_id:, sender:, body:))
  }

  "select m.id, m.user_id, u.username as sender, m.body
from messages m
join users u on u.id = m.user_id
order by m.id;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `create_session` query
/// defined in `./src/server/db/sql/create_session.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_session(
  db: pog.Connection,
  arg_1: String,
  arg_2: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into sessions (token, user_id)
values ($1, $2);
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `create_user` query
/// defined in `./src/server/db/sql/create_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreateUserRow {
  CreateUserRow(id: Int, username: String)
}

/// Runs the `create_user` query
/// defined in `./src/server/db/sql/create_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_user(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
) -> Result(pog.Returned(CreateUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use username <- decode.field(1, decode.string)
    decode.success(CreateUserRow(id:, username:))
  }

  "insert into users (username, password_hash)
values ($1, $2)
returning id, username;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `delete_message` query
/// defined in `./src/server/db/sql/delete_message.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_message(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "delete from messages
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `delete_session` query
/// defined in `./src/server/db/sql/delete_session.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_session(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "delete from sessions
where token = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_user_by_token` query
/// defined in `./src/server/db/sql/find_user_by_token.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserByTokenRow {
  FindUserByTokenRow(id: Int, username: String)
}

/// Runs the `find_user_by_token` query
/// defined in `./src/server/db/sql/find_user_by_token.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user_by_token(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(FindUserByTokenRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use username <- decode.field(1, decode.string)
    decode.success(FindUserByTokenRow(id:, username:))
  }

  "select u.id, u.username
from users u
join sessions s on s.user_id = u.id
where s.token = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_user_by_username` query
/// defined in `./src/server/db/sql/find_user_by_username.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserByUsernameRow {
  FindUserByUsernameRow(id: Int, username: String, password_hash: String)
}

/// Runs the `find_user_by_username` query
/// defined in `./src/server/db/sql/find_user_by_username.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user_by_username(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(FindUserByUsernameRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use username <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    decode.success(FindUserByUsernameRow(id:, username:, password_hash:))
  }

  "select id, username, password_hash
from users
where username = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `insert_message` query
/// defined in `./src/server/db/sql/insert_message.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type InsertMessageRow {
  InsertMessageRow(id: Int, user_id: Int, sender: String, body: String)
}

/// Runs the `insert_message` query
/// defined in `./src/server/db/sql/insert_message.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_message(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(InsertMessageRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use sender <- decode.field(2, decode.string)
    use body <- decode.field(3, decode.string)
    decode.success(InsertMessageRow(id:, user_id:, sender:, body:))
  }

  "with inserted as (
  insert into messages (user_id, body)
  values ($1, $2)
  returning id, user_id, body
)
select i.id, i.user_id, u.username as sender, i.body
from inserted i
join users u on u.id = i.user_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `message_author` query
/// defined in `./src/server/db/sql/message_author.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MessageAuthorRow {
  MessageAuthorRow(user_id: Int)
}

/// Runs the `message_author` query
/// defined in `./src/server/db/sql/message_author.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn message_author(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(MessageAuthorRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.int)
    decode.success(MessageAuthorRow(user_id:))
  }

  "select user_id
from messages
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
