import client/model.{
  type Model, type Msg, UserClickedDelete, UserSubmittedDraft, UserUpdatedDraft,
}
import client/ui/button
import client/ui/card
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared/message.{type Message}

pub fn page(model: Model) -> Element(Msg) {
  html.div([class("min-h-dvh bg-surface-900 flex justify-center p-6")], [
    html.div([class("w-full max-w-md flex flex-col gap-4")], [
      html.h1([class("mb-2")], [html.text("Messages")]),
      error(model),
      html.div([class("flex flex-col gap-3")], list.map(model.messages, bubble)),
      composer(model),
    ]),
  ])
}

fn error(model: Model) -> Element(Msg) {
  case model.error {
    Some(reason) -> html.p([class("text-red-400")], [html.text(reason)])
    None -> element.none()
  }
}

fn bubble(msg: Message) -> Element(Msg) {
  card.card([], [
    html.div([class("flex items-start justify-between gap-2")], [
      html.p([class("text-primary-400 font-semibold")], [html.text(msg.sender)]),
      button.danger([event.on_click(UserClickedDelete(msg.id))], "Delete"),
    ]),
    html.p([], [html.text(msg.body)]),
  ])
}

fn composer(model: Model) -> Element(Msg) {
  html.form(
    [class("flex gap-2"), event.on_submit(fn(_) { UserSubmittedDraft })],
    [
      html.input([
        class(
          "flex-1 rounded-2xl bg-surface-800 px-4 py-2 text-surface-50 "
          <> "placeholder:text-surface-400 focus:outline-none",
        ),
        attribute.value(model.draft),
        attribute.placeholder("Type a message…"),
        event.on_input(UserUpdatedDraft),
      ]),
      button.primary([attribute.type_("submit")], "Send"),
    ],
  )
}
