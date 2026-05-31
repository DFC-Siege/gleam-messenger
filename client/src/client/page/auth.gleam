import client/model.{
  type Model, type Msg, SubmittedLogin, SubmittedRegister, UpdatedPassword,
  UpdatedUsername,
}
import client/router.{type Route, Register}
import client/ui/button
import client/ui/card
import client/ui/layout
import gleam/option.{None, Some}
import lustre/attribute.{class, href}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn view(model: Model, route: Route) -> Element(Msg) {
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

  layout.shell([
    card.card([class("w-full max-w-sm")], [
      card.title(title),
      html.form(
        [class("flex flex-col gap-3"), event.on_submit(fn(_) { submit })],
        [
          field("Username", "text", model.username_input, UpdatedUsername),
          field("Password", "password", model.password_input, UpdatedPassword),
          error(model),
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

fn error(model: Model) -> Element(Msg) {
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
