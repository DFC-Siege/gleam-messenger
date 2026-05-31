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
        attempt = 0;
        schedule();
      } else {
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
