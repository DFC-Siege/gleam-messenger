import gleam/erlang/process.{type Name}
import gleam/option.{Some}
import pog

pub fn config(name: Name(pog.Message)) -> pog.Config {
  pog.default_config(pool_name: name)
  |> pog.host("localhost")
  |> pog.port(5433)
  |> pog.database("messenger")
  |> pog.user("messenger")
  |> pog.password(Some("messenger"))
}
