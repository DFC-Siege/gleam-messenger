import lustre/effect.{type Effect}

@external(javascript, "./socket_ffi.mjs", "connect")
fn connect(
  url: String,
  on_message: fn(String) -> Nil,
  on_give_up: fn() -> Nil,
) -> Nil

pub fn listen(
  url: String,
  to_msg: fn(String) -> msg,
  on_give_up: msg,
) -> Effect(msg) {
  use dispatch <- effect.from
  connect(url, fn(text) { dispatch(to_msg(text)) }, fn() {
    dispatch(on_give_up)
  })
}
