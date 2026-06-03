import argus
import gleam/bit_array
import gleam/crypto

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
