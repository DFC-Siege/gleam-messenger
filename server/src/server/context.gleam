import pog
import server/hub.{type Hub}

pub type Context {
  Context(db: pog.Connection, hub: Hub)
}
