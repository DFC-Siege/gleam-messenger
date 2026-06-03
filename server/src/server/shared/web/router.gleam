import server/shared/web/page
import wisp.{type Request, type Response}

// Everything the browser needs is either a static asset or the HTML shell that
// boots the Lustre server component. All application behaviour lives in the
// server component itself, reached over the `/ws` WebSocket.
pub fn handle_request(req: Request) -> Response {
  use <- wisp.serve_static(req, under: "/static", from: static_directory())

  page.document()
  |> wisp.html_response(200)
}

fn static_directory() -> String {
  let assert Ok(priv) = wisp.priv_directory("server")
  priv <> "/static"
}
