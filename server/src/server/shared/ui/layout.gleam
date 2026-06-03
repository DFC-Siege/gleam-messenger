import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html

pub fn shell(children: List(Element(msg))) -> Element(msg) {
  html.div(
    [class("min-h-dvh bg-surface-900 flex justify-center p-6")],
    children,
  )
}
