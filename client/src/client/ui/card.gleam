import lustre/attribute.{type Attribute, class}
import lustre/element.{type Element}
import lustre/element/html

pub fn card(
  attrs: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  let classes = "rounded-2xl bg-surface-800 p-6 shadow-lg"
  html.div([class(classes), ..attrs], children)
}

pub fn title(text: String) -> Element(msg) {
  html.h2([class("mb-2")], [html.text(text)])
}
