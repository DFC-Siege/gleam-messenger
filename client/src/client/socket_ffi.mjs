export function connect(url, onMessage) {
  const open = () => {
    const ws = new WebSocket(url);
    ws.addEventListener("message", (event) => onMessage(event.data));
    ws.addEventListener("close", () => setTimeout(open, 1000));
  };
  open();
}
