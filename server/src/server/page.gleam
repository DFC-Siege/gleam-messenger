import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/server_component

// The HTML document served for every page. It contains the Lustre server
// component runtime, an empty <lustre-server-component> element, and a small
// shim that wires the connection URL to a token kept in localStorage so that
// sessions survive reloads.
pub fn document() -> String {
  html.html([attribute.attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute.attribute("charset", "utf-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.title([], "Messenger"),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/app.css"),
      ]),
      server_component.script(),
    ]),
    html.body([], [
      server_component.element([attribute.id("app")], []),
      shim(),
    ]),
  ])
  |> element.to_document_string
}

fn shim() -> Element(msg) {
  html.script(
    [],
    "
    const sc = document.querySelector('lustre-server-component');
    const token = localStorage.getItem('token');
    sc.setAttribute('route', token ? '/ws?token=' + encodeURIComponent(token) : '/ws');

    sc.addEventListener('auth', (event) => {
      localStorage.setItem('token', event.detail);
      sc.setAttribute('route', '/ws?token=' + encodeURIComponent(event.detail));
    });

    sc.addEventListener('logout', () => {
      localStorage.removeItem('token');
      sc.setAttribute('route', '/ws');
    });
    ",
  )
}
