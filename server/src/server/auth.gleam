import argus
import gleam/bit_array
import gleam/crypto
import gleam/http/request
import gleam/result
import gleam/string
import pog
import server/db/sessions
import shared/user.{type User}
import wisp.{type Request, type Response}

pub fn hash_password(password: String) -> String {
  let assert Ok(hashes) = argus.hash(argus.hasher(), password, argus.gen_salt())
  hashes.encoded_hash
}

pub fn verify_password(password: String, encoded_hash: String) -> Bool {
  case argus.verify(encoded_hash, password) {
    Ok(valid) -> valid
    Error(_) -> False
  }
}

pub fn generate_token() -> String {
  crypto.strong_random_bytes(32)
  |> bit_array.base16_encode
}

pub fn bearer_token(req: Request) -> Result(String, Nil) {
  use header <- result.try(request.get_header(req, "authorization"))
  case string.split(header, " ") {
    ["Bearer", token] -> Ok(token)
    _ -> Error(Nil)
  }
}

pub fn require_user(
  db: pog.Connection,
  req: Request,
  next: fn(User) -> Response,
) -> Response {
  case bearer_token(req) {
    Ok(token) ->
      case sessions.find_user_by_token(db, token) {
        Ok(user) -> next(user)
        Error(_) -> wisp.response(401)
      }
    Error(_) -> wisp.response(401)
  }
}
