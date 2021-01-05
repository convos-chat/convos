import Conversation from '../../assets/store/Conversation';
import {getSocket} from '../../assets/js/Socket';

const socket = getSocket('/events').update({url: 'wss://example.convos.chat'});

test('constructor', () => {
  let c = new Conversation({});
  expect(c.name).toBe('ERR');

  c = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});
  expect(c.color).toBe('#6bafb2');
  expect(c.connection_id).toBe('irc-freenode');
  expect(c.conversation_id).toBe('#convos');
  expect(c.errors).toBe(0);
  expect(c.frozen).toBe('');
  expect(c.is_private).toBe(false);
  expect(c.messages).toEqual([]);
  expect(c.modes).toEqual({});
  expect(c.name).toBe('#convos');
  expect(c.path).toBe('/chat/irc-freenode/%23convos');
  expect(c.status).toBe('pending');
  expect(c.topic).toBe('');
  expect(c.unread).toBe(0);
});

test('load', async () => {
  const c = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});
  expect(c.status).toBe('pending');

  c.messagesOp.perform = mockMessagesOpPerform({
    body: {end: true, messages: [{from: 'supergirl', message: 'm one', type: 'private', ts: '2020-01-20T09:01:50.001Z'}]},
    status: 200,
  })
  await c.load();
  expect(c.messagesOp.performed).toEqual({connection_id: 'irc-freenode', conversation_id: '#convos', limit: 40});
  expect(c.status).toBe('success');
  expect(socket.queue.length).toBe(1);
  expect(socket.queue[0]).toEqual({id: "1", method: 'send', connection_id: 'irc-freenode', conversation_id: '#convos', message: '/names'});

  c.messagesOp.perform = mockMessagesOpPerform({
    body: {end: true, messages: [{from: 'superman', message: 'm two', type: 'private', ts: '2020-01-20T09:01:50.001Z'}]},
    status: 200,
  })
  delete c.messagesOp.performed;
  await c.load({around: '2020-01-10T09:01:50.001Z'});
  expect(c.messagesOp.performed).toEqual({around: '2020-01-10T09:01:50.001Z', connection_id: 'irc-freenode', conversation_id: '#convos', limit: 30});
});

test('load start/end history', () => {
  const c = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});
  const messages = [1, 2, 3].map(i => ({ts: '2020-01-01T09:01:01.001Z'.replace(/1/g, i)}));

  const reset = () => c.update({historyStartAt: null, historyStopAt: null});

  reset();
  c._setEndOfStream({}, {after: '2020-02-10T09:00:01.001Z', before: '2020-02-10T09:00:00.001Z'});
  expect(c.historyStartAt).toBe(null);
  expect(c.historyStopAt).toBe(null);

  reset();
  c._setEndOfStream({after: '2020-02-10T09:00:02.002Z', before: '2020-02-10T09:00:00.002Z'}, {});
  expect(c.historyStartAt).toBe(null);
  expect(c.historyStopAt).toBe(null);

  reset();
  c._setEndOfStream({after: '2020-02-10T09:00:03.003Z'}, {messages, before: '2020-02-10T09:00:00.003Z'});
  expect(c.historyStartAt).toBe(null);
  expect(c.historyStopAt.toISOString()).toBe('2020-03-03T09:03:03.003Z');

  reset();
  c._setEndOfStream({before: '2020-02-10T09:00:03.003Z'}, {messages, after: '2020-02-10T09:00:00.003Z'});
  expect(c.historyStartAt.toISOString()).toBe('2020-01-01T09:01:01.001Z');
  expect(c.historyStopAt).toBe(null);

  c.update({historyStartAt: new Date(), historyStopAt: new Date()});
  c._setEndOfStream({around: '2020-02-10T09:00:03.003Z'}, {messages, after: '2020-02-10T09:00:00.003Z'});
  expect(c.historyStopAt).toBe(null);
  expect(c.historyStartAt).toBeTruthy();

  c.update({historyStartAt: new Date(), historyStopAt: new Date()});
  c._setEndOfStream({around: '2020-02-10T09:00:03.003Z'}, {messages, before: '2020-02-10T09:00:00.003Z'});
  expect(c.historyStartAt).toBe(null);
  expect(c.historyStopAt).toBeTruthy();

  messages.pop();
  messages.pop();
  expect(messages.length).toBe(1);
  reset();
  const t0 = new Date().valueOf();
  c._setEndOfStream({after: '2000-01-01T00:00:00.000Z', before: '2100-12-31T00:00:00.000Z'}, {messages});
  expect(c.historyStartAt.valueOf()).toBeGreaterThanOrEqual(t0);
  expect(c.historyStopAt.valueOf()).toBeGreaterThanOrEqual(t0);
});

test('load skip', () => {
  const c = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});

  // Prevent loading multiple times
  c.update({status: 'loading'});
  expect(c._skipLoad({})).toBe(true);

  // Skip load if no messages and success (already loaded)
  c.update({status: 'success'});
  expect(c._skipLoad({})).toBe(true);
  c.update({messages: [{ts: new Date('2020-01-20T09:00:00.001Z')}]});
  expect(c._skipLoad({})).toBe(false);

  // Skip at start/end of history
  expect(c._skipLoad({before: '2020-01-20T09:01:50.001Z'})).toBe(false);
  expect(c._skipLoad({after: '2020-01-20T09:01:50.001Z'})).toBe(false);
  c.update({historyStartAt: new Date(), historyStopAt: new Date()});
  expect(c._skipLoad({before: '2020-01-20T09:01:50.001Z'})).toBe(true);
  expect(c._skipLoad({after: '2020-01-20T09:01:50.001Z'})).toBe(true);

  // Skip around if alread loaded
  expect(c._skipLoad({around: '2020-01-20T09:00:00.001Z'})).toBe(true);
  expect(c._skipLoad({around: '2020-01-20T09:01:01.001Z'})).toBe(false);
});

test('addMessage channel', () => {
  const c = new Conversation({connection_id: 'irc-localhost', conversation_id: '#test'});
  expect(c.unread).toBe(0);

  c.addMessage({from: 'supergirl', highlight: true, message: 'n1', type: 'private', yourself: true});
  expect(c.unread).toBe(0);

  c.addMessage({from: 'supergirl', highlight: true, message: 'n2', type: 'private'});
  expect(c.unread).toBe(1);
  expect(c.lastNotification.title).toBe('supergirl in #test');
  expect(c.lastNotification.body).toBe('n2');

  document.hasFocus = () => true;
  c.addMessage({from: 'supergirl', highlight: true, message: 'n3', type: 'private'});
  expect(c.lastNotification.body).toBe('n2');
  document.hasFocus = () => false;
});

test('addMessage private', () => {
  const c = new Conversation({connection_id: 'irc-localhost', conversation_id: 'supergirl'});
  expect(c.unread).toBe(0);

  // Do not increase unread when sent by yourself
  c.addMessage({from: 'superwoman', message: 'n1', type: 'private', yourself: true});
  expect(c.unread).toBe(0);

  // Show notification
  c.addMessage({from: 'supergirl', message: 'n2', type: 'private'});
  expect(c.unread).toBe(1);
  expect(c.lastNotification.title).toBe('supergirl');
  expect(c.lastNotification.body).toBe('n2');

  // Do not show notification when document has focus
  document.hasFocus = () => true;
  c.addMessage({from: 'supergirl', message: 'n3', type: 'private'});
  expect(c.unread).toBe(2);
  expect(c.lastNotification.body).toBe('n2');
  document.hasFocus = () => false;

  // Do not increase unread on "notice"
  c.addMessage({from: 'Convos', message: 'n3', type: 'notice'});
  expect(c.unread).toBe(2);
});

test('addMessage without historyStopAt', () => {
  const c = new Conversation({connection_id: 'irc-localhost', conversation_id: 'supergirl'});

  c.addMessage({from: 'superwoman', message: 'dropped', type: 'private'});
  expect(c.messages.length).toBe(0);

  c.update({historyStopAt: new Date()});
  c.addMessage({from: 'superwoman', message: 'dropped', type: 'private'});
  expect(c.messages.length).toBe(1);
});

test('openWindow', () => {
  const c = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});

  expect(c.window).toBe(null);

  let events = {};
  let open = {};
  const w = {addEventListener: (name, cb) => { events[name] = cb }};
  window.open = (url, name, features) => { open = {url, name, features}; return w };
  c.openWindow('/video/meet.jit.si/irc-freenode-%23convos');
  expect(c.window).toBe(w);
  expect(open).toEqual({url: '/video/meet.jit.si/irc-freenode-%23convos', name: 'chat_irc_freenode__23convos', features: ''});
  expect(Object.keys(events).sort()).toEqual(['beforeunload', 'close']);

  c.openWindow('/video/meet.jit.si/irc-freenode-%23convos', 'foo');
  expect(open).toEqual({url: '/video/meet.jit.si/irc-freenode-%23convos', name: 'foo', features: ''});

  events.beforeunload();
  expect(c.window).toBe(null);
});

test('videoInfo', () => {
  const c = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});

  expect(c.videoInfo()).toEqual({
    icon: 'video',
    roomName: 'irc-freenode-%23convos',
  });

  c.update({videoService: 'https://meet.jit.si/whatever'});
  expect(c.videoInfo()).toEqual({
    convosUrl: '/video/meet.jit.si/irc-freenode-%23convos',
    realUrl: 'https://meet.jit.si/whatever/irc-freenode-%23convos',
    icon: 'video',
    roomName: 'irc-freenode-%23convos',
  });

  c.participants([{nick: 'superwoman', me: true}]);
  expect(c.videoInfo()).toEqual({
    convosUrl: '/video/meet.jit.si/irc-freenode-%23convos?nick=superwoman',
    realUrl: 'https://meet.jit.si/whatever/irc-freenode-%23convos',
    icon: 'video',
    roomName: 'irc-freenode-%23convos',
  });

  c.addMessage({from: 'supergirl', highlight: false, message: c.videoInfo().realUrl, type: 'private'});
  expect(c.unread).toBe(1);
  expect(c.lastNotification.title).toBe('supergirl in #convos');
  expect(c.lastNotification.body).toBe('Do you want to join the Jitsi video chat with "#convos"?');
});

function mockMessagesOpPerform(res) {
  return function(params) {
    this.performed = params;
    this.emit('start', params); // TODO
    this.parse(res);
  };
}
