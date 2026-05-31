import client/model
import client/vendor
import client/view
import lustre

pub fn main() {
  vendor.register()
  let app = lustre.application(model.init, model.update, view.page)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
