import client/chat.{
  type Model, type Msg, ClickedDelete, ClickedLogout, SubmittedDraft,
  UpdatedDraft,
}
import client/ui/button
import client/ui/card
import client/ui/layout
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute.{class, href}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared/message.{type Message}
import shared/user.{type User}

pub fn view(model: Model, user: User) -> Element(Msg) {
  layout.shell([
    html.div([class("w-full max-w-md flex flex-col gap-4")], [
      header(user),
      error(model),
      html.div(
        [class("flex flex-col gap-3")],
        list.map(model.messages, bubble(_, user)),
      ),
      composer(model),
    ]),
  ])
}

fn header(user: User) -> Element(Msg) {
  html.div([class("flex items-center justify-between")], [
    html.h1([], [html.text("Messages")]),
    html.div([class("flex items-center gap-3")], [
      html.a([href("/viewer"), class("text-sm text-surface-400")], [
        html.text("3D"),
      ]),
      html.span([class("text-sm text-surface-400")], [html.text(user.username)]),
      button.ghost([event.on_click(ClickedLogout)], "Log out"),
    ]),
  ])
}

fn bubble(msg: Message, user: User) -> Element(Msg) {
  let actions = case msg.user_id == user.id {
    True -> [button.danger([event.on_click(ClickedDelete(msg.id))], "Delete")]
    False -> []
  }
  card.card([], [
    html.div([class("flex items-start justify-between gap-2")], [
      html.p([class("text-primary-400 font-semibold")], [html.text(msg.sender)]),
      ..actions
    ]),
    html.p([], [html.text(msg.body)]),
  ])
}

fn composer(model: Model) -> Element(Msg) {
  html.form([class("flex gap-2"), event.on_submit(fn(_) { SubmittedDraft })], [
    html.input([
      class(
        "flex-1 rounded-2xl bg-surface-800 px-4 py-2 text-surface-50 "
        <> "placeholder:text-surface-400 focus:outline-none",
      ),
      attribute.value(model.draft),
      attribute.placeholder("Type a message…"),
      event.on_input(UpdatedDraft),
    ]),
    button.primary([attribute.type_("submit")], "Send"),
  ])
}

fn error(model: Model) -> Element(Msg) {
  case model.error {
    Some(reason) -> html.p([class("text-danger-400")], [html.text(reason)])
    None -> element.none()
  }
}
