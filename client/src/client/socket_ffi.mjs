// Reconnecting websocket with exponential backoff + jitter.
//
// - Live drops (socket had opened, then closed) retry forever with backoff.
// - Repeated handshake failures (closed before ever opening) are how an
//   expired token *or* a down server look from JS — indistinguishable here.
//   After a few, we give up and call `onGiveUp`, letting the app adjudicate
//   over HTTP (401 vs network error).
export function connect(url, onMessage, onGiveUp) {
  const baseDelay = 500;
  const maxDelay = 15000;
  const maxHandshakeFails = 5;

  let attempt = 0;
  let handshakeFails = 0;
  let stopped = false;

  const schedule = () => {
    const backoff = Math.min(maxDelay, baseDelay * 2 ** attempt);
    const jitter = Math.random() * baseDelay;
    setTimeout(open, backoff + jitter);
  };

  const open = () => {
    if (stopped) return;
    let opened = false;
    const ws = new WebSocket(url);

    ws.addEventListener("open", () => {
      opened = true;
      attempt = 0;
      handshakeFails = 0;
    });

    ws.addEventListener("message", (event) => onMessage(event.data));

    ws.addEventListener("close", () => {
      if (stopped) return;
      if (opened) {
        // A live connection dropped — reset and retry quickly.
        attempt = 0;
        schedule();
      } else {
        // Never connected: auth reject or server unreachable.
        handshakeFails += 1;
        if (handshakeFails >= maxHandshakeFails) {
          stopped = true;
          onGiveUp();
          return;
        }
        attempt += 1;
        schedule();
      }
    });
  };

  open();
}
