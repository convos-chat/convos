import Socket from '../assets/js/Socket';
import {socket} from '../assets/js/Socket';
import {timer} from '../assets/js/util';

const WebSocket = global.WebSocket = window.WebSocket = function(url) {
  WebSocket.constructed++;
  this.url = url;
  this.closed = [];
  this.sent = [];
  this.send = (msg) => this.sent.push(JSON.parse(msg));
  this.close = (code, reason) => (this.closed = [code, reason]);
}

WebSocket.constructed = 0;
WebSocket.CONNECTING = 0;
WebSocket.OPEN = 1;
WebSocket.CLOSING = 2;
WebSocket.CLOSED = 3;

test('constructor', () => {
  const socket = new Socket();

  expect(socket.keepaliveInterval).toBe(10000);
  expect(socket.keepaliveMessage).toEqual({});
  expect(socket.online).toBe(true);
  expect(socket.readyState).toBe(WebSocket.CLOSED);
  expect(socket.url).toBe('');
});

test('open', async () => {
  const before = WebSocket.constructed;
  const socket = new Socket().update({keepaliveInterval: 5, url: 'wss://example.convos.chat'});

  expect(socket.keepClosed).toBe(true);
  expect(socket.keepaliveTid).toBe(undefined);
  expect(socket.ws.url).toBe(undefined);

  socket.open();
  socket.open();
  socket.open();
  await socket.on('update');
  expect(socket.ws.url).toBe('wss://example.convos.chat');
  expect(socket.keepaliveTid).not.toBe(undefined);
  expect(socket.keepClosed).toBe(false);

  socket.close();
  socket.open();
  expect(WebSocket.constructed - before).toBe(2);
});

test('close', async () => {
  const socket = new Socket().update({keepaliveInterval: 5, url: 'wss://example.convos.chat'});

  expect(socket.open()).toEqual(socket);
  socket.ws.readyState = WebSocket.CONNECTING;
  await socket.on('update');
  expect(socket.is('connecting')).toBe(true);

  expect(socket.close()).toEqual(socket);
  expect(socket.is('closed')).toBe(true);
  expect(socket.keepClosed).toBe(true);
  expect(socket.keepaliveTid).toBe(undefined);
  expect(socket.ws.url).toBe(undefined);
});

test('send', async () => {
  const socket = new Socket().update({url: 'wss://example.convos.chat'});

  later(
    () => (socket.ws.readyState = WebSocket.OPEN),
    () => socket.ws.onopen({}),
    () => socket.ws.onmessage({data: '{"id":"1","sent":true}'}),
  );

  const res = await socket.send({foo: 42});
  expect(socket.ws.sent).toEqual([{id: '1', foo: 42}]);
  expect(res).toEqual({id: '1', sent: true});
});

test('reconnectIn', async () => {
  const socket = new Socket().update({keepaliveInterval: 5, url: 'wss://example.convos.chat'});

  expect(socket.reconnectIn({})).toEqual(1000);
  expect(socket.reconnectIn({code: 1008})).toEqual(false);
  expect(socket.reconnectIn({code: 1011})).toEqual(false);

  socket.open();
  expect(socket.keepaliveTid).not.toBe(undefined);

  socket.ws.onclose({code: 1000});
  expect(socket.keepaliveTid).toBe(undefined);
  expect(socket.reconnectTid).not.toBe(undefined);

  socket.close();
  expect(socket.reconnectTid).toBe(undefined);
});

test('toFunction', async () => {
  const socket = new Socket().update({keepaliveInterval: 5, url: 'wss://example.convos.chat'}).toFunction();
  expect(socket().is('closed')).toBe(true);

  later(
    () => (socket().ws.readyState = WebSocket.OPEN),
    () => socket().ws.onopen({}),
    () => socket().ws.onmessage({data: '{"id":"1","sent":true}'}),
  );

  const res = await socket({});
  expect(res).toEqual({id: '1', sent: true});
});

test('socket', () => {
  const sock_a = socket('sock_a');
  expect(socket('sock_a')).toEqual(sock_a);
  expect(socket('sock_b')).not.toEqual(sock_a);

  socket('sock_a').update({url: 'wss://example.convos.chat'});
  const p = socket('sock_a', 'method_x');
  expect(Promise.resolve(p)).toEqual(p);
});

function later(...cb) {
  let p = timer(1, cb.shift());
  while (cb.length) p = p.then(timer(1, cb.shift()))
  return p.catch(err => console.error(err));
}
