import lustre/effect.{type Effect}

@external(javascript, "./socket_ffi.mjs", "connect")
fn connect(url: String, on_message: fn(String) -> Nil) -> Nil

pub fn listen(url: String, to_msg: fn(String) -> msg) -> Effect(msg) {
  effect.from(fn(dispatch) { connect(url, fn(text) { dispatch(to_msg(text)) }) })
}
