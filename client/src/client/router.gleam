import gleam/uri.{type Uri}

pub type Route {
  Login
  Register
  Chat
}

pub fn from_uri(u: Uri) -> Route {
  case uri.path_segments(u.path) {
    ["login"] -> Login
    ["register"] -> Register
    _ -> Chat
  }
}

pub fn to_path(route: Route) -> String {
  case route {
    Login -> "/login"
    Register -> "/register"
    Chat -> "/"
  }
}
