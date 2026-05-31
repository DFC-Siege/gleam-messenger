import client/auth
import client/auth/view as auth_view
import client/chat
import client/chat/view as chat_view
import client/router.{type Route, Chat, Login, Viewer}
import client/viewer
import gleam/option.{type Option, None, Some}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import modem

pub type Model {
  Model(
    route: Route,
    session: Option(auth.Session),
    auth: auth.Model,
    chat: chat.Model,
  )
}

pub type Msg {
  RouteChanged(Route)
  AuthMsg(auth.Msg)
  ChatMsg(chat.Msg)
}

pub fn init(_flags) -> #(Model, Effect(Msg)) {
  let route = case modem.initial_uri() {
    Ok(uri) -> router.from_uri(uri)
    Error(_) -> Login
  }

  let model = Model(route:, session: None, auth: auth.init(), chat: chat.init())

  #(
    model,
    effect.batch([
      modem.init(fn(uri) { RouteChanged(router.from_uri(uri)) }),
      effect.map(auth.restore(), AuthMsg),
    ]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    RouteChanged(route) -> #(Model(..model, route:), effect.none())

    AuthMsg(sub) -> {
      let #(auth_model, eff, out) = auth.update(model.auth, sub)
      let model = Model(..model, auth: auth_model)
      let eff = effect.map(eff, AuthMsg)
      case out {
        auth.Nothing -> #(model, eff)

        auth.Authenticated(session) -> {
          let #(chat_model, chat_eff) = chat.enter(session.token)
          #(
            Model(..model, session: Some(session), chat: chat_model),
            effect.batch([
              eff,
              effect.map(chat_eff, ChatMsg),
              modem.push(router.to_path(Chat), None, None),
            ]),
          )
        }

        auth.SessionExpired -> #(
          Model(..model, session: None, chat: chat.init()),
          effect.batch([eff, modem.push(router.to_path(Login), None, None)]),
        )
      }
    }

    ChatMsg(sub) -> {
      let #(chat_model, eff, out) = chat.update(model.chat, sub)
      let eff = effect.map(eff, ChatMsg)
      case out {
        chat.Nothing -> #(Model(..model, chat: chat_model), eff)

        chat.ConnectionLost -> #(
          Model(..model, chat: chat_model),
          effect.batch([eff, effect.map(auth.recheck(), AuthMsg)]),
        )

        chat.RequestLogout -> #(
          Model(..model, session: None, chat: chat.init()),
          effect.batch([
            eff,
            logout(model.session),
            modem.push(router.to_path(Login), None, None),
          ]),
        )
      }
    }
  }
}

fn logout(session: Option(auth.Session)) -> Effect(Msg) {
  case session {
    Some(session) -> effect.map(auth.logout(session.token), AuthMsg)
    None -> effect.none()
  }
}

pub fn view(model: Model) -> Element(Msg) {
  case model.session {
    None -> element.map(auth_view.view(model.auth, model.route), AuthMsg)

    Some(session) ->
      case model.route {
        Viewer -> viewer.view()
        _ -> element.map(chat_view.view(model.chat, session.user), ChatMsg)
      }
  }
}
