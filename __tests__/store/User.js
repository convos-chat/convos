import Socket from '../../assets/js/Socket';
import TestWebSocket from '../../assets/js/TestWebSocket';
import User from '../../assets/store/User';

global.WebSocket = window.WebSocket = TestWebSocket;

test('ensureDialog connection', () => {
  const user = new User({});

  const conn = user.ensureDialog({connection_id: 'irc-foo'});
  expect(conn.connection_id).toBe('irc-foo');
  expect(user.activeDialog.connection_id).toBe('');

  // Upgrade activeDialog
  user.setActiveDialog({connection_id: 'irc-bar'});
  user.ensureDialog({connection_id: 'irc-bar'});
  expect(user.activeDialog.connection_id).toBe('irc-bar');
  expect(user.activeDialog.dialog_id).toBe(undefined);

  // Upgrade activeDialog from connection
  user.setActiveDialog({connection_id: 'irc-foo', dialog_id: '#cf'});
  expect(user.activeDialog.frozen).toBe('Not found.');
  conn.ensureDialog({dialog_id: '#cf'});
  expect(user.activeDialog.dialog_id).toBe('#cf');
  expect(user.activeDialog.frozen).toBe('');
});

test('ensureDialog dialog', () => {
  const user = new User({});

  const dialog = user.ensureDialog({connection_id: 'irc-foo', dialog_id: '#cf'});
  expect(dialog.connection_id).toBe('irc-foo');
  expect(user.activeDialog.connection_id).toBe('');
  expect(user.activeDialog.dialog_id).toBe('notifications');

  // Upgrade activeDialog
  user.setActiveDialog({connection_id: 'irc-bar', dialog_id: '#cr'});
  expect(user.findDialog({connection_id: 'irc-bar', dialog_id: '#cr'})).toBe(null);
  user.ensureDialog({connection_id: 'irc-bar', dialog_id: '#cr'});
  expect(user.activeDialog.connection_id).toBe('irc-bar');
  expect(user.activeDialog.dialog_id).toBe('#cr');
});

test('removeDialog connection', () => {
  const user = new User({});

  const conn = user.ensureDialog({connection_id: 'irc-baz'});
  user.update({activeDialog: conn});
  expect(user.activeDialog == conn).toBe(true);

  user.removeDialog(conn);
  expect(user.activeDialog != conn).toBe(true);
  expect(user.activeDialog.connection_id).toBe('irc-baz');
  expect(user.connections.size).toBe(0);
});

test('removeDialog dialog', () => {
  const user = new User({});

  const conn = user.ensureDialog({connection_id: 'irc-bax'});
  const dialog = user.ensureDialog({connection_id: 'irc-bax', dialog_id: '#cx'});

  user.update({activeDialog: dialog});
  expect(user.activeDialog == dialog).toBe(true);

  user.removeDialog(dialog);
  expect(user.activeDialog != dialog).toBe(true);
  expect(user.activeDialog.connection_id).toBe('irc-bax');
  expect(user.activeDialog.dialog_id).toBe('#cx');
  expect(user.connections.size).toBe(1);
  expect(user.dialogs().length).toBe(0);
});

test('load success', async () => {
  const user = new User({socket: new Socket()});
  const socket = user.socket;

  // Start loading data
  socket.update({url: 'wss://example.convos.by/events'});
  expect(user.status).toBe('pending');
  user.load();
  await user.on('update');
  expect(user.status).toBe('loading');

  // Send the queued load() message
  socket.ws.dispatchEvent('open');
  expect(cleanWaiting(socket.getWaitingMessages())).toEqual([{
    id: '1',
    method: 'load',
    object: 'user',
    params: {connections: true, dialogs: true},
    ts: true,
    waitingForResponse: true
  }]);

  expect(user.default_connection).toBe('irc://chat.freenode.net:6697/%23convos');
  expect(user.email).toBe('');
  expect(user.forced_connection).toBe(false);
  expect(user.highlightKeywords).toEqual([]);

  // Get response
  socket.ws.dispatchEvent('message', {
    data: {
      id : '1',
      user: {
        email: 'superwoman@convos.chat',
        default_connection: 'irc://chat.freenode.net',
        forced_connection: true,
        highlight_keywords: ['foo', 'bar'],
      },
    },
  });

  await user.on('update');
  expect(user.default_connection).toBe('irc://chat.freenode.net');
  expect(user.email).toBe('superwoman@convos.chat');
  expect(user.forced_connection).toBe(true);
  expect(user.highlightKeywords).toEqual(['foo', 'bar']);
  expect(user.status).toBe('success');
});

test('load error', async () => {
  const user = new User({socket: new Socket()});
  const socket = user.socket;

  // Start loading data
  socket.update({url: 'wss://example.convos.by/events'});
  user.load();
  await user.on('update');

  // Get error response
  socket.ws.dispatchEvent('open');
  socket.ws.dispatchEvent('message', {data: {id : '1', errors: [{message: 'Yikes'}]}});
  await user.on('update');
  expect(user.status).toBe('error');
  expect(user.default_connection).toBe('irc://chat.freenode.net:6697/%23convos');
  expect(user.email).toBe('');
  expect(user.forced_connection).toBe(false);
  expect(user.highlightKeywords).toEqual([]);
});

test('reload', async () => {
  const user = new User({socket: new Socket()});
  const socket = user.socket;
  socket.update({debug: 'yes'});

  // Start loading user data
  socket.reconnectIn = () => 50;
  socket.update({url: 'wss://example.convos.by/events'});
  user.load();
  await socket.on('update');
  await user.on('update');
  expect(socket.getWaitingMessages()).toEqual([]);
  expect(socket.queue.length).toEqual(1);
  expect(user.status).toBe('loading');

  // Close before data is loaded
  socket.ws.dispatchEvent('close');
  await socket.on('update');
  expect(socket.ws.readyState).toBe(WebSocket.CLOSED);
  await socket.on('update');
  expect(socket.ws.readyState).toBe(WebSocket.CONNECTING);
  expect(user.status).toBe('loading');
  expect(socket.getWaitingMessages()).toEqual([]);
  expect(socket.queue.length).toEqual(1);

  // Reconnect while loading
  socket.ws.readyState = WebSocket.OPEN;
  socket.ws.dispatchEvent('open');
  socket.ws.dispatchEvent('message', {data: {id : '1', user: {email: 'superwoman@convos.chat'}}});
  await user.on('update');
  expect(user.status).toBe('success');
  expect(user.email).toBe('superwoman@convos.chat');

  // Close after loaded
  socket.ws.dispatchEvent('close');
  await user.on('update');
  expect(socket.ws.readyState).toBe(WebSocket.CLOSED);
  expect(user.status).toBe('pending');

  // Reconnect after loaded
  await socket.on('update');
  expect(socket.ws.readyState).toBe(WebSocket.CONNECTING);
  socket.ws.dispatchEvent('open');
  await user.on('update');
  expect(user.status).toBe('loading');
});

function cleanWaiting(list) {
  return list.map(item => { return {...item, ts: item.ts ? true : false} });
}
