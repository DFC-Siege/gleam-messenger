import gleam/http.{Options}
import gleam/http/request
import gleam/http/response
import server/auth/routes as auth_routes
import server/chat/routes as chat_routes
import server/context.{type Context}
import server/hub
import wisp.{type Request, type Response}

pub fn handle_request(ctx: Context, req: Request) -> Response {
  case req.method {
    Options -> add_cors(wisp.response(204))
    _ -> add_cors(handle(ctx, req))
  }
}

fn handle(ctx: Context, req: Request) -> Response {
  case request.path_segments(req) {
    ["api", "register"] -> auth_routes.register(ctx, req)
    ["api", "login"] -> auth_routes.login(ctx, req)
    ["api", "session"] -> auth_routes.logout(ctx, req)
    ["api", "me"] -> auth_routes.me(ctx, req)
    ["api", "messages"] -> chat_routes.collection(ctx, req)
    ["api", "messages", id] -> chat_routes.single(ctx, req, id)
    ["api", "crash"] -> {
      hub.crash(ctx.hub)
      wisp.response(204)
    }
    _ -> wisp.not_found()
  }
}

fn add_cors(resp: Response) -> Response {
  resp
  |> response.set_header("access-control-allow-origin", "*")
  |> response.set_header(
    "access-control-allow-methods",
    "GET, POST, DELETE, OPTIONS",
  )
  |> response.set_header(
    "access-control-allow-headers",
    "content-type, authorization",
  )
  |> response.set_header("access-control-max-age", "86400")
}
