import pog
import server/shared/hub.{type Hub}

pub type Context {
  Context(db: pog.Connection, hub: Hub)
}
