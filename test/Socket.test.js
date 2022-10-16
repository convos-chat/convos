import Socket from '../assets/js/Socket';
import WebSocket from '../assets/js/TestWebSocket';
import {expect, test} from 'vitest';
import {getSocket} from '../assets/js/Socket';
import {timer} from '../assets/js/util';

global.WebSocket = window.WebSocket = WebSocket;

test('constructor', () => {
  const socket = new Socket();

  expect(socket.keepaliveInterval).toBe(10000);
  expect(socket.readyState).toBe(WebSocket.CLOSED);
  expect(socket.url).toBe('');
});

test('open', async () => {
  const before = WebSocket.constructed;
  const socket = new Socket().update({keepaliveInterval: 5});

  socket.reconnectTid = 42; // This should not be changed on a failed open()
  socket.open();
  expect(socket.error).toBe('Can\'t open WebSocket connection without URL.');
  expect(socket.keepClosed).toBe(true);
  expect(socket.keepaliveTid).toBe(undefined);
  expect(socket.reconnectTid).toBe(42);
  expect(socket.ws.url).toBe(undefined);

  delete socket.reconnectTid;
  socket.update({url: 'wss://example.convos.chat'});
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

  const res = await new Promise(r => socket.send({foo: 42}, r));
  delete res.stopPropagation;
  expect(socket.ws.sent).toEqual([{id: '1', foo: 42}]);
  expect(socket.getWaitingMessages()).toEqual([]);
  expect(res).toEqual({bubbles: true, id: '1', sent: true});
});

test('send - error', async () => {
  const socket = new Socket().update({url: 'wss://example.convos.chat'});

  later(
    () => (socket.ws.readyState = WebSocket.OPEN),
    () => socket.ws.onopen({}),
    () => socket.ws.onmessage({data: '{"errors":[{"message":"yikes"}]}'}),
  );

  const res = await new Promise(r => socket.send({foo: 42}, r));
  delete res.stopPropagation;
  expect(socket.ws.sent).toEqual([{id: '1', foo: 42}]);
  expect(socket.getWaitingMessages()).toEqual([]);
  expect(res).toEqual({bubbles: true, errors: [{message: 'yikes'}]});
});

test('reconnectIn', () => {
  const socket = new Socket().update({keepaliveInterval: 5, url: 'wss://example.convos.chat'});

  expect(socket.reconnectIn({})).toEqual(1000);
  expect(socket.reconnectIn({code: 1008})).toEqual(false);
  expect(socket.reconnectIn({code: 1011})).toEqual(false);

  socket.open();
  expect(socket.keepaliveTid).not.toBe(undefined);

  socket.ws.onclose({code: 1000});
  expect(socket.closed).toBe(1);
  expect(socket.reconnectIn({})).toEqual(1000);
  expect(socket.keepaliveTid).toBe(undefined);
  expect(socket.reconnectTid).not.toBe(undefined);

  socket.close();
  expect(socket.reconnectTid).toBe(undefined);

  // Test backoff
  [2, 3, 4, 5, 6].forEach(exp => {
    socket.open();
    socket.ws.onclose({code: 1000});
    expect(socket.closed).toBe(exp);
    expect(socket.reconnectIn({})).toEqual(exp > 5 ? 10000 : (exp * 2) * 1000);
  });
});

test('reconnect', async () => {
  const socket = new Socket().update({keepaliveInterval: 5, url: 'wss://example.convos.chat'});
  socket.update({debug: 'yes'});
  expect(socket.keepaliveTid).toBe(undefined);
  expect(socket.reconnectTid).toBe(undefined);
  expect(socket.readyState).toBe(WebSocket.CLOSED);

  socket.reconnectIn = () => 10;

  // Open the WebSocket
  socket.open();
  await socket.on('update');
  expect(socket.readyState).toBe(WebSocket.CONNECTING);
  expect(socket.keepaliveTid).not.toBe(undefined);
  expect(socket.reconnectTid).toBe(undefined);

  // Close the WebSocket
  socket.ws.onerror({message: 'Yikes'});
  expect(socket.error).toBe('Yikes');

  socket.ws.onclose({});
  await socket.on('update');
  expect(socket.readyState).toBe(WebSocket.CLOSED);
  expect(socket.keepaliveTid).toBe(undefined);
  expect(socket.reconnectTid).not.toBe(undefined);

  // Wait for socket.open() after reconnectIn() ms
  await socket.on('update');
  expect(socket.readyState).toBe(WebSocket.CONNECTING);
  expect(socket.error).toBe('');

  socket.update({error: 'Yikes'});
  expect(socket.error).toBe('Yikes');
  socket.ws.onopen({});
  expect(socket.error).toBe('');
});

test('socket', () => {
  const sock_a = getSocket('sock_a');
  expect(getSocket('sock_a')).toEqual(sock_a);
  expect(getSocket('sock_b')).not.toEqual(sock_a);
});

function later(...cb) {
  let p = timer(1, cb.shift());
  while (cb.length) p = p.then(timer(1, cb.shift()))
  return p.catch(err => console.error(err));
}
