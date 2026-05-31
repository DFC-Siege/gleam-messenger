import client/ui/card
import client/ui/layout
import lustre/attribute.{attribute, class, href}
import lustre/element.{type Element, element}
import lustre/element/html

pub fn view() -> Element(msg) {
  layout.shell([
    html.div([class("w-full max-w-md flex flex-col gap-4")], [
      html.div([class("flex items-center justify-between")], [
        html.h1([], [html.text("3D viewer")]),
        html.a([href("/"), class("text-sm text-surface-400")], [
          html.text("Back to chat"),
        ]),
      ]),
      card.card([class("overflow-hidden p-0")], [
        element(
          "model-viewer",
          [
            attribute("src", "/model.glb"),
            attribute("alt", "A 3D model"),
            attribute("camera-controls", ""),
            attribute("auto-rotate", ""),
            attribute("ar", ""),
            class("block w-full h-96 bg-surface-800"),
          ],
          [],
        ),
      ]),
    ]),
  ])
}
