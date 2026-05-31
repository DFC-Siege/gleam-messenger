import client/app
import client/vendor
import lustre

pub fn main() {
  vendor.register()
  let application = lustre.application(app.init, app.update, app.view)
  let assert Ok(_) = lustre.start(application, "#app", Nil)

  Nil
}
