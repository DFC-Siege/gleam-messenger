import lustre/attribute.{type Attribute, class}
import lustre/element.{type Element}
import lustre/element/html

fn base(
  extra: String,
  attrs: List(Attribute(msg)),
  label: String,
) -> Element(msg) {
  let classes =
    "inline-flex items-center justify-center gap-2 rounded-2xl px-4 py-2 "
    <> "font-semibold transition-colors focus:outline-none "
    <> extra
  html.button([class(classes), ..attrs], [html.text(label)])
}

pub fn primary(attrs: List(Attribute(msg)), label: String) -> Element(msg) {
  base("bg-primary-500 text-white hover:bg-primary-400", attrs, label)
}

pub fn ghost(attrs: List(Attribute(msg)), label: String) -> Element(msg) {
  base("bg-transparent text-primary-400 hover:bg-surface-700", attrs, label)
}

pub fn danger(attrs: List(Attribute(msg)), label: String) -> Element(msg) {
  base("bg-danger-500 text-white hover:bg-danger-400", attrs, label)
}
