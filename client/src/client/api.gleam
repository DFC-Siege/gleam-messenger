import gleam/http.{type Method}
import gleam/http/request
import gleam/json.{type Json}
import lustre/effect.{type Effect}
import rsvp.{type Handler}

pub fn get(url: String, token: String, handler: Handler(msg)) -> Effect(msg) {
  send(http.Get, url, token, "", handler)
}

pub fn post(
  url: String,
  token: String,
  body: Json,
  handler: Handler(msg),
) -> Effect(msg) {
  send(http.Post, url, token, json.to_string(body), handler)
}

pub fn delete(url: String, token: String, handler: Handler(msg)) -> Effect(msg) {
  send(http.Delete, url, token, "", handler)
}

fn send(
  method: Method,
  url: String,
  token: String,
  body: String,
  handler: Handler(msg),
) -> Effect(msg) {
  case request.to(url) {
    Ok(req) ->
      req
      |> request.set_method(method)
      |> request.set_header("authorization", "Bearer " <> token)
      |> request.set_header("content-type", "application/json")
      |> request.set_body(body)
      |> rsvp.send(handler)
    Error(_) -> effect.none()
  }
}
