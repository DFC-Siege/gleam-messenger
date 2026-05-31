import client/model.{
  type Model, type Msg, type Session, ClickedDelete, ClickedLogout,
  SubmittedDraft, SubmittedLogin, SubmittedRegister, UpdatedDraft,
  UpdatedPassword, UpdatedUsername,
}
import client/router.{type Route, Register}
import client/ui/button
import client/ui/card
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute.{class, href}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared/message.{type Message}

pub fn page(model: Model) -> Element(Msg) {
  case model.session {
    Some(session) -> chat(model, session)
    None ->
      case model.route {
        Register -> auth_form(model, Register)
        _ -> auth_form(model, router.Login)
      }
  }
}

// --- auth pages ---

fn auth_form(model: Model, route: Route) -> Element(Msg) {
  let registering = route == Register
  let title = case registering {
    True -> "Create account"
    False -> "Welcome back"
  }
  let submit = case registering {
    True -> SubmittedRegister
    False -> SubmittedLogin
  }
  let cta = case registering {
    True -> "Register"
    False -> "Log in"
  }

  shell([
    card.card([class("w-full max-w-sm")], [
      card.title(title),
      html.form(
        [class("flex flex-col gap-3"), event.on_submit(fn(_) { submit })],
        [
          field("Username", "text", model.username_input, UpdatedUsername),
          field("Password", "password", model.password_input, UpdatedPassword),
          auth_error(model),
          button.primary([attribute.type_("submit"), class("w-full")], cta),
        ],
      ),
      switch_link(registering),
    ]),
  ])
}

fn field(
  label: String,
  kind: String,
  value: String,
  on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([class("flex flex-col gap-1 text-sm text-surface-300")], [
    html.text(label),
    html.input([
      class(
        "rounded-2xl bg-surface-800 px-4 py-2 text-surface-50 focus:outline-none",
      ),
      attribute.type_(kind),
      attribute.value(value),
      event.on_input(on_input),
    ]),
  ])
}

fn auth_error(model: Model) -> Element(Msg) {
  case model.auth_error {
    Some(reason) ->
      html.p([class("text-danger-400 text-sm")], [html.text(reason)])
    None -> element.none()
  }
}

fn switch_link(registering: Bool) -> Element(Msg) {
  let #(prompt, path, label) = case registering {
    True -> #("Already have an account? ", "/login", "Log in")
    False -> #("Need an account? ", "/register", "Register")
  }
  html.p([class("mt-4 text-sm text-surface-400")], [
    html.text(prompt),
    html.a([href(path)], [html.text(label)]),
  ])
}

// --- chat ---

fn chat(model: Model, session: Session) -> Element(Msg) {
  shell([
    html.div([class("w-full max-w-md flex flex-col gap-4")], [
      header(session),
      error(model),
      html.div(
        [class("flex flex-col gap-3")],
        list.map(model.messages, bubble(_, session)),
      ),
      composer(model),
    ]),
  ])
}

fn header(session: Session) -> Element(Msg) {
  html.div([class("flex items-center justify-between")], [
    html.h1([], [html.text("Messages")]),
    html.div([class("flex items-center gap-3")], [
      html.span([class("text-sm text-surface-400")], [
        html.text(session.user.username),
      ]),
      button.ghost([event.on_click(ClickedLogout)], "Log out"),
    ]),
  ])
}

fn bubble(msg: Message, session: Session) -> Element(Msg) {
  let actions = case msg.user_id == session.user.id {
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

fn shell(children: List(Element(Msg))) -> Element(Msg) {
  html.div(
    [class("min-h-dvh bg-surface-900 flex justify-center p-6")],
    children,
  )
}
