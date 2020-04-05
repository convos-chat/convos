import Omnibus from '../assets/store/Omnibus';
import Route from '../assets/store/Route';

global.Notification = window.Notification = function(title, params) {
  global.Notification.last = this;
  this.close = function() {};
  this.title = title;
  this.params = params;
}

global.WebSocket = window.WebSocket = function(url) {
  this.url = url;
}

navigator.registerProtocolHandler = (protocol, url, message) => {
  navigator.registerProtocolHandler.last = {message, protocol, url};
};

test('constructor', () => {
  const bus = new Omnibus();

  expect(bus.notificationCloseDelay).toBe(5000);
  expect(bus.wantNotifications).toBe(null);
  expect(bus.wantNotifications).toBe(null);
  expect(bus.wsUrl).toBe('');
});

test('registerProtocol', () => {
  const bus = new Omnibus();
  bus.update({route: new Route()});
  bus.route.update({baseUrl: 'http://convos.example.com'});

  bus.registerProtocol('irc', false);
  expect(bus.protocols.irc).toBe(false);

  bus.registerProtocol('irc', true);
  expect(bus.protocols.irc).toBe(true);
  expect(navigator.registerProtocolHandler.last).toEqual({
    message: 'Convos wants to handle "irc" links',
    protocol: 'irc',
    url: 'http://convos.example.com/register?uri=%s',
  });
});

test('start', async () => {
  const bus = new Omnibus();
  const route = new Route();

  let serviceWorker;
  bus.on('serviceWorker', e => {serviceWorker = e});

  navigator.serviceWorker = {register: (url) => new Promise(r => r({url}))};
  route.update({baseUrl: 'http://localhost/base'});
  bus.start({route, wsUrl: 'ws://localhost/events'});

  await bus.on('update');
  expect(bus.wsUrl).toBe('ws://localhost/events');
  expect(serviceWorker).toEqual({url: '/base/sw.js'});

  const errors = [];
  bus.on('error', e => errors.push(e));

  let error = {
    colno: 24,
    error: 'err!',
    filename: 'test.js',
    lineno: 42,
    message: 'oops!',
    reason: 'huh?',
    returnValue: true,
  };

  window.dispatchEvent(new ErrorEvent('error', error));
  window.dispatchEvent(new ErrorEvent('unhandledrejection', error));

  errors.forEach(e => delete e.timeStamp);
  expect(errors).toEqual([
    {colno: 24, error: 'err!', filename: 'test.js', lineno: 42, message: 'oops!', type: 'error'},
    {reason: undefined, returnValue: true, type: 'unhandledrejection'},
  ]);
});

test('websocket events', async () => {
  const bus = new Omnibus();

  const n = {};
  ['close', 'open'].forEach(k => { n[k] = 0; bus.on(k, () => n[k]++) });

  bus.update({wsUrl: 'ws://localhost/events'});
  bus.send('whatever');
  bus.ws.onopen();
  expect(n).toEqual({close: 0, open: 1});

  bus.ws.onclose();
  expect(n).toEqual({close: 1, open: 1});
});

test('websocket keepalive', () => {
  const bus = new Omnibus();
  const messages = [];
  bus.ws = {readyState: 1, send: (msg) => messages.push(msg)};

  bus._keepalive();
  expect(messages).toEqual(['{"method":"ping"}']);
  messages.shift();

  bus.send('ping');
  expect(bus.messageCb).toEqual({});
  expect(bus.wsSendQueue).toEqual([]);
  expect(messages.map(m => JSON.parse(m))).toEqual([{id: '0', method: 'ping'}]);
});

test('websocket reconnect backoff', () => {
  const bus = new Omnibus();
  bus.update({wsUrl: 'ws://localhost/events'});

  // backoff reconnect
  for (let i = 1; i < 12; i++) {
    bus._ws();
    bus.ws.onclose();
    expect(bus._wsReconnectDelay).toBe(500 * i);
  }

  // restart backoff
  bus._ws();
  bus.ws.onclose();
  expect(bus._wsReconnectDelay).toBe(500);
});

test('websocket dispatch', () => {
  const bus = new Omnibus();

  const messages = [];
  bus.on('message', e => messages.push(e));

  bus.update({wsUrl: 'ws://localhost/events'});
  bus.send('ping');
  expect(bus.ws.url).toBe('ws://localhost/events');

  bus.ws.onmessage({data: '{"event":"pong","id":"42"}'});
  messages.forEach(m => delete m.stopPropagation);
  expect(messages.shift()).toEqual({bubbles: true, dispatchTo: 'wsEventPong', event: 'pong', id: '42'});

  bus.ws.onmessage({data: '{"event":"state","id":"42","type":"frozen"}'});
  messages.forEach(m => delete m.stopPropagation);
  expect(messages.shift()).toEqual({bubbles: true, dispatchTo: 'wsEventFrozen', event: 'state', id: '42', type: 'frozen'});

  bus.ws.onmessage({data: '{"errors":[]}'});
  messages.forEach(m => delete m.stopPropagation);
  expect(messages.shift()).toEqual({bubbles: true, dispatchTo: 'wsEventError', errors: []});

  bus.send({message: '/kick robin'}, e => { e.stopPropagation(); messages.push(e) });
  bus.ws.onmessage({data: '{"event":"sent","id":"1","message":"/kick robin"}'});
  messages.forEach(m => delete m.stopPropagation);
  expect(messages.length).toBe(1);
  expect(messages.shift()).toEqual({bubbles: false, command: ['kick', 'robin'], dispatchTo: 'wsEventSentKick', event: 'sent', id: '1', message: '/kick robin'});
});

test('requestPermissionToNotify', done => {
  const bus = new Omnibus();
  bus.update({defaultTitle: 'RequestTest', wantNotifications: null});

  let permission = 'denied';
  Notification.permission = 'default';
  Notification.requestPermission = (cb) => cb(Notification.permission = permission);
  expect(bus.notifyPermission).toBe('default');

  bus.requestPermissionToNotify();
  expect(bus.wantNotifications).toBe(false);

  permission = 'granted';
  bus.requestPermissionToNotify();
  expect(bus.notifyPermission).toBe('granted');
  expect(bus.wantNotifications).toBe(true);
  expect(removeCallbacks(Notification.last))
    .toEqual({params: {body: 'You have enabled notifications.', force: true}, title: 'RequestTest'});

  [false, true].forEach(bool => {
    bus.requestPermissionToNotify(bool);
    expect(bus.wantNotifications).toBe(bool);
  });

  delete Notification.requestPermission;
  bus.requestPermissionToNotify(status => {
    expect(status).toBe('granted');
    done();
  });
});

test('notify', done => {
  const bus = new Omnibus();
  bus._hasFocus = () => false;

  Notification.last = undefined;
  expect(bus.notify('Convos', 'Some message')).toBe(null);
  expect(Notification.last).toBe(undefined);

  Notification.permission = 'granted';
  bus.update({notificationCloseDelay: 100, wantNotifications: true});
  expect(typeof Notification.last.close).toBe('function');
  expect(typeof Notification.last.onclick).toBe('function');
  expect(removeCallbacks(Notification.last))
    .toEqual({params: {body: 'You have enabled notifications.', force: true}, title: 'Convos'});

  expect(removeCallbacks(bus.notify('Convos', 'Test')))
    .toEqual({params: {body: 'Test'}, title: 'Convos'});

  bus._hasFocus = () => true;
  expect(bus.notify('Convos', 'Test')).toBe(null);

  // Check that the close callback gets called
  Notification.last.close = done;
});

function removeCallbacks(obj) {
  const clone = {...obj};
  Object.keys(clone).forEach(k => (typeof clone[k] == 'function' && delete clone[k]));
  return clone;
}
