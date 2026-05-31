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
      list.each(clients, fn(client) { process.send(client, event) })
      actor.continue(clients)
    }
  }
}
