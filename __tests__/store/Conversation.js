import Conversation from '../../assets/store/Conversation';
import {getSocket} from '../../assets/js/Socket';

const socket = getSocket('/events').update({url: 'wss://example.convos.chat'});

test('constructor', () => {
  let d = new Conversation({});
  expect(d.name).toBe('ERR');

  d = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});
  expect(d.color).toBe('#6bafb2');
  expect(d.connection_id).toBe('irc-freenode');
  expect(d.conversation_id).toBe('#convos');
  expect(d.errors).toBe(0);
  expect(d.frozen).toBe('');
  expect(d.is_private).toBe(false);
  expect(d.messages).toEqual([]);
  expect(d.modes).toEqual({});
  expect(d.name).toBe('#convos');
  expect(d.path).toBe('/chat/irc-freenode/%23convos');
  expect(d.status).toBe('pending');
  expect(d.topic).toBe('');
  expect(d.unread).toBe(0);
});

test('load', async () => {
  const d = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});
  expect(d.status).toBe('pending');

  d.messagesOp.perform = mockMessagesOpPerform({
    body: {end: true, messages: [{from: 'supergirl', message: 'm one', type: 'private', ts: '2020-01-20T09:01:50.001Z'}]},
    status: 200,
  })
  await d.load();
  expect(d.messagesOp.performed).toEqual({connection_id: 'irc-freenode', conversation_id: '#convos', limit: 40});
  expect(d.status).toBe('success');
  expect(socket.queue.length).toBe(1);
  expect(socket.queue[0]).toEqual({id: "1", method: 'send', connection_id: 'irc-freenode', conversation_id: '#convos', message: '/names'});

  d.messagesOp.perform = mockMessagesOpPerform({
    body: {end: true, messages: [{from: 'superman', message: 'm two', type: 'private', ts: '2020-01-20T09:01:50.001Z'}]},
    status: 200,
  })
  delete d.messagesOp.performed;
  await d.load({around: '2020-01-10T09:01:50.001Z'});
  expect(d.messagesOp.performed).toEqual({around: '2020-01-10T09:01:50.001Z', connection_id: 'irc-freenode', conversation_id: '#convos', limit: 30});
});

test('load start/end history', () => {
  const d = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});
  const messages = [1, 2, 3].map(i => ({ts: '2020-01-01T09:01:01.001Z'.replace(/1/g, i)}));

  const reset = () => d.update({historyStartAt: null, historyStopAt: null});

  reset();
  d._setEndOfStream({}, {after: '2020-02-10T09:00:01.001Z', before: '2020-02-10T09:00:00.001Z'});
  expect(d.historyStartAt).toBe(null);
  expect(d.historyStopAt).toBe(null);

  reset();
  d._setEndOfStream({after: '2020-02-10T09:00:02.002Z', before: '2020-02-10T09:00:00.002Z'}, {});
  expect(d.historyStartAt).toBe(null);
  expect(d.historyStopAt).toBe(null);

  reset();
  d._setEndOfStream({after: '2020-02-10T09:00:03.003Z'}, {messages, before: '2020-02-10T09:00:00.003Z'});
  expect(d.historyStartAt).toBe(null);
  expect(d.historyStopAt.toISOString()).toBe('2020-03-03T09:03:03.003Z');

  reset();
  d._setEndOfStream({before: '2020-02-10T09:00:03.003Z'}, {messages, after: '2020-02-10T09:00:00.003Z'});
  expect(d.historyStartAt.toISOString()).toBe('2020-01-01T09:01:01.001Z');
  expect(d.historyStopAt).toBe(null);

  d.update({historyStartAt: new Date(), historyStopAt: new Date()});
  d._setEndOfStream({around: '2020-02-10T09:00:03.003Z'}, {messages, after: '2020-02-10T09:00:00.003Z'});
  expect(d.historyStopAt).toBe(null);
  expect(d.historyStartAt).toBeTruthy();

  d.update({historyStartAt: new Date(), historyStopAt: new Date()});
  d._setEndOfStream({around: '2020-02-10T09:00:03.003Z'}, {messages, before: '2020-02-10T09:00:00.003Z'});
  expect(d.historyStartAt).toBe(null);
  expect(d.historyStopAt).toBeTruthy();

  messages.pop();
  messages.pop();
  expect(messages.length).toBe(1);
  reset();
  const t0 = new Date().valueOf();
  d._setEndOfStream({after: '2000-01-01T00:00:00.000Z', before: '2100-12-31T00:00:00.000Z'}, {messages});
  expect(d.historyStartAt.valueOf()).toBeGreaterThanOrEqual(t0);
  expect(d.historyStopAt.valueOf()).toBeGreaterThanOrEqual(t0);
});

test('load skip', () => {
  const d = new Conversation({connection_id: 'irc-freenode', conversation_id: '#convos'});

  // Prevent loading multiple times
  d.update({status: 'loading'});
  expect(d._skipLoad({})).toBe(true);

  // Skip load if no messages and success (already loaded)
  d.update({status: 'success'});
  expect(d._skipLoad({})).toBe(true);
  d.update({messages: [{ts: new Date('2020-01-20T09:00:00.001Z')}]});
  expect(d._skipLoad({})).toBe(false);

  // Skip at start/end of history
  expect(d._skipLoad({before: '2020-01-20T09:01:50.001Z'})).toBe(false);
  expect(d._skipLoad({after: '2020-01-20T09:01:50.001Z'})).toBe(false);
  d.update({historyStartAt: new Date(), historyStopAt: new Date()});
  expect(d._skipLoad({before: '2020-01-20T09:01:50.001Z'})).toBe(true);
  expect(d._skipLoad({after: '2020-01-20T09:01:50.001Z'})).toBe(true);

  // Skip around if alread loaded
  expect(d._skipLoad({around: '2020-01-20T09:00:00.001Z'})).toBe(true);
  expect(d._skipLoad({around: '2020-01-20T09:01:01.001Z'})).toBe(false);
});

test('addMessage channel', () => {
  const d = new Conversation({connection_id: 'irc-localhost', conversation_id: '#test'});
  expect(d.unread).toBe(0);

  d.addMessage({from: 'supergirl', highlight: true, message: 'n1', type: 'private', yourself: true});
  expect(d.unread).toBe(0);

  d.addMessage({from: 'supergirl', highlight: true, message: 'n2', type: 'private'});
  expect(d.unread).toBe(1);
  expect(d.lastNotification.title).toBe('supergirl in #test');
  expect(d.lastNotification.body).toBe('n2');

  document.hasFocus = () => true;
  d.addMessage({from: 'supergirl', highlight: true, message: 'n3', type: 'private'});
  expect(d.lastNotification.body).toBe('n2');
  document.hasFocus = () => false;
});

test('addMessage private', () => {
  const d = new Conversation({connection_id: 'irc-localhost', conversation_id: 'supergirl'});
  expect(d.unread).toBe(0);

  // Do not increase unread when sent by yourself
  d.addMessage({from: 'superwoman', message: 'n1', type: 'private', yourself: true});
  expect(d.unread).toBe(0);

  // Show notification
  d.addMessage({from: 'supergirl', message: 'n2', type: 'private'});
  expect(d.unread).toBe(1);
  expect(d.lastNotification.title).toBe('supergirl');
  expect(d.lastNotification.body).toBe('n2');

  // Do not show notification when document has focus
  document.hasFocus = () => true;
  d.addMessage({from: 'supergirl', message: 'n3', type: 'private'});
  expect(d.unread).toBe(2);
  expect(d.lastNotification.body).toBe('n2');
  document.hasFocus = () => false;

  // Do not increase unread on "notice"
  d.addMessage({from: 'Convos', message: 'n3', type: 'notice'});
  expect(d.unread).toBe(2);
});

function mockMessagesOpPerform(res) {
  return function(params) {
    this.performed = params;
    this.emit('start', params); // TODO
    this.parse(res);
  };
}
