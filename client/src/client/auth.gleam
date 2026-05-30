import lustre/effect.{type Effect}

@external(javascript, "./auth_ffi.mjs", "get_token")
pub fn get_token() -> String

@external(javascript, "./auth_ffi.mjs", "set_token")
fn set_token(token: String) -> Nil

@external(javascript, "./auth_ffi.mjs", "clear_token")
fn clear_token() -> Nil

pub fn store_token(token: String) -> Effect(msg) {
  use _ <- effect.from
  set_token(token)
}

pub fn forget_token() -> Effect(msg) {
  use _ <- effect.from
  clear_token()
}
