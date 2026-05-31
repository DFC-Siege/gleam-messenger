import gleam/list
import gleam/string

pub type Error {
  UsernameTooShort
  UsernameTooLong
  PasswordTooShort
  PasswordTooLong
}

pub fn validate(username: String, password: String) -> Result(Nil, List(Error)) {
  let errors =
    []
    |> check(string.length(username) >= 3, UsernameTooShort)
    |> check(string.length(username) <= 32, UsernameTooLong)
    |> check(string.length(password) >= 8, PasswordTooShort)
    |> check(string.length(password) <= 128, PasswordTooLong)

  case errors {
    [] -> Ok(Nil)
    _ -> Error(list.reverse(errors))
  }
}

pub fn message(error: Error) -> String {
  case error {
    UsernameTooShort -> "Username must be at least 3 characters"
    UsernameTooLong -> "Username must be at most 32 characters"
    PasswordTooShort -> "Password must be at least 8 characters"
    PasswordTooLong -> "Password must be at most 128 characters"
  }
}

fn check(errors: List(Error), ok: Bool, error: Error) -> List(Error) {
  case ok {
    True -> errors
    False -> [error, ..errors]
  }
}
