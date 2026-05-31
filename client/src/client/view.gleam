import client/model.{type Model, type Msg}
import client/page/auth
import client/page/chat
import client/page/viewer
import client/router.{Register, Viewer}
import gleam/option.{None, Some}
import lustre/element.{type Element}

pub fn page(model: Model) -> Element(Msg) {
  case model.session {
    Some(session) ->
      case model.route {
        Viewer -> viewer.view()
        _ -> chat.view(model, session)
      }
    None ->
      case model.route {
        Register -> auth.view(model, Register)
        _ -> auth.view(model, router.Login)
      }
  }
}
