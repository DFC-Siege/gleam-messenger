import client/model
import client/view
import lustre

pub fn main() {
  let app = lustre.application(model.init, model.update, view.page)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
