import gleam/json
import gleam/option.{type Option, None, Some}
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/server_component
import server/auth as login
import server/auth/session.{type Session}
import server/auth/sessions
import server/auth/view as login_view
import server/chat
import server/chat/view as chat_view
import server/shared/context.{type Context}

/// Arguments handed to the server component when it boots for a connection.
/// `session` is `Some` when the connection arrived with a valid token.
pub type Flags {
  Flags(ctx: Context, session: Option(Session))
}

pub type Model {
  Model(
    ctx: Context,
    session: Option(Session),
    login: login.Model,
    chat: chat.Model,
  )
}

pub type Msg {
  LoginMsg(login.Msg)
  ChatMsg(chat.Msg)
}

pub fn app() -> lustre.App(Flags, Model, Msg) {
  lustre.application(init, update, view)
}

fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let model =
    Model(ctx: flags.ctx, session: None, login: login.init(), chat: chat.init())

  case flags.session {
    Some(session) -> enter_chat(model, session)
    None -> #(model, effect.none())
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LoginMsg(sub) -> {
      let #(login_model, eff, out) = login.update(model.ctx, model.login, sub)
      let model = Model(..model, login: login_model)
      let eff = effect.map(eff, LoginMsg)
      case out {
        login.Nothing -> #(model, eff)
        login.Authenticated(session) -> {
          let #(model, enter_eff) = enter_chat(model, session)
          #(model, effect.batch([eff, enter_eff]))
        }
      }
    }

    ChatMsg(sub) ->
      case model.session {
        None -> #(model, effect.none())
        Some(session) -> {
          let #(chat_model, eff, out) =
            chat.update(model.ctx, session, model.chat, sub)
          let model = Model(..model, chat: chat_model)
          let eff = effect.map(eff, ChatMsg)
          case out {
            chat.Nothing -> #(model, eff)
            chat.RequestLogout -> {
              sessions.delete(model.ctx.db, session.token)
              #(
                Model(..model, session: None, login: login.init()),
                effect.batch([
                  eff,
                  server_component.emit("logout", json.null()),
                ]),
              )
            }
          }
        }
      }
  }
}

fn enter_chat(model: Model, session: Session) -> #(Model, Effect(Msg)) {
  let #(chat_model, chat_eff) = chat.enter(model.ctx)
  #(
    Model(..model, session: Some(session), chat: chat_model),
    effect.map(chat_eff, ChatMsg),
  )
}

fn view(model: Model) -> Element(Msg) {
  case model.session {
    Some(session) ->
      element.map(chat_view.view(model.chat, session.user), ChatMsg)
    None -> element.map(login_view.view(model.login), LoginMsg)
  }
}
