import gleam/erlang/process.{type Name, type Subject}
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import shared/event.{type Event}

pub type Hub =
  Subject(Op)

pub opaque type Op {
  Subscribe(client: Subject(Event))
  Unsubscribe(client: Subject(Event))
  Publish(event: Event)
  Crash
}

// Debug-only: deliberately crash the hub to test supervisor restart.
pub fn crash(hub: Hub) -> Nil {
  process.send(hub, Crash)
}

pub fn supervised(name: Name(Op)) -> supervision.ChildSpecification(Hub) {
  supervision.worker(fn() {
    actor.new([])
    |> actor.on_message(handle)
    |> actor.named(name)
    |> actor.start
  })
}

pub fn subscribe(hub: Hub, client: Subject(Event)) -> Nil {
  process.send(hub, Subscribe(client))
}

pub fn unsubscribe(hub: Hub, client: Subject(Event)) -> Nil {
  process.send(hub, Unsubscribe(client))
}

pub fn publish(hub: Hub, event: Event) -> Nil {
  process.send(hub, Publish(event))
}

fn handle(
  clients: List(Subject(Event)),
  op: Op,
) -> actor.Next(List(Subject(Event)), Op) {
  case op {
    Subscribe(client) -> actor.continue([client, ..clients])
    Unsubscribe(client) ->
      actor.continue(list.filter(clients, fn(c) { c != client }))
    Publish(event) -> {
      // Drop clients whose owning process has died (e.g. a server component
      // whose WebSocket closed) so the subscriber list stays bounded.
      let alive = list.filter(clients, is_alive)
      list.each(alive, fn(client) { process.send(client, event) })
      actor.continue(alive)
    }
    Crash -> panic as "intentional hub crash for testing"
  }
}

fn is_alive(client: Subject(Event)) -> Bool {
  case process.subject_owner(client) {
    Ok(pid) -> process.is_alive(pid)
    Error(_) -> False
  }
}
