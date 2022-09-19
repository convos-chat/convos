function TestWebSocket(url) {
  TestWebSocket.constructed++;
  this.url = url;
  this.closed = [];
  this.readyState = TestWebSocket.CONNECTING;
  this.sent = [];
  this.send = (msg) => this.sent.push(JSON.parse(msg));
  this.close = (code, reason) => (this.closed = [code, reason]);

  this.dispatchEvent = (name, e = {}) => {
    if (e.data) e.data = JSON.stringify(e.data);
    if (name === 'close') this.readyState = TestWebSocket.CLOSED;
    if (name === 'open') this.readyState = TestWebSocket.OPEN;
    this['on' + name](e);
  };
}

TestWebSocket.constructed = 0;
TestWebSocket.CONNECTING = WebSocket.CONNECTING || 0;
TestWebSocket.OPEN = WebSocket.OPEN || 1;
TestWebSocket.CLOSING = WebSocket.CLOSING || 2;
TestWebSocket.CLOSED = WebSocket.CLOSED || 3;

export default TestWebSocket;
