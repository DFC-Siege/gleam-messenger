import server/auth/user.{type User}

/// An authenticated connection: the bearer token and the user it belongs to.
pub type Session {
  Session(token: String, user: User)
}
