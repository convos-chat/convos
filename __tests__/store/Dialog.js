import Dialog from '../../assets/store/Dialog';
import {socket as getSocket} from '../../assets/js/Socket';

const socket = getSocket('/events').update({url: 'wss://example.convos.chat'});

test('constructor', () => {
  let d = new Dialog({});
  expect(d.name).toBe('ERR');

  d = new Dialog({connection_id: 'irc-freenode', dialog_id: '#convos'});
  expect(d.color).toBe('#6bafb2');
  expect(d.connection_id).toBe('irc-freenode');
  expect(d.dialog_id).toBe('#convos');
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
  const d = new Dialog({connection_id: 'irc-freenode', dialog_id: '#convos'});
  expect(d.status).toBe('pending');

  d.messagesOp.perform = mockMessagesOpPerform({
    body: {end: true, messages: [{from: 'supergirl', message: 'Cool beans', type: 'private', ts: '2020-01-20T09:01:50.001Z'}]},
    status: 200,
  })
  await d.load();
  expect(d.messagesOp.performed).toEqual({connection_id: 'irc-freenode', dialog_id: '#convos', limit: 60});
  expect(d.status).toBe('success');
  expect(socket.queue.length).toBe(1);
  expect(socket.queue[0]).toEqual({id: "1", method: 'send', connection_id: 'irc-freenode', dialog_id: '#convos', message: '/names'});

  d.messagesOp.perform = mockMessagesOpPerform({status: 500});
  delete d.messagesOp.performed;
  await d.load({before: 'maybe'});
  expect(d.messagesOp.performed).toBe(undefined);
  expect(d.status).toBe('success');
  await d.load({after: 'maybe'});
  expect(d.messagesOp.performed).toBe(undefined);
  expect(d.status).toBe('success');

  d.messagesOp.perform = mockMessagesOpPerform({
    body: {end: true, messages: [{from: 'supergirl', message: 'Something new', type: 'private', ts: '2020-01-20T09:02:50.001Z'}]},
    status: 200,
  });
  d.update({endOfHistory: false, status: 'pending'});
  await d.load({after: 'maybe'});
  expect(d.messagesOp.performed).toEqual({after: '2020-01-20T09:01:50.001Z', limit: 200, connection_id: 'irc-freenode', dialog_id: '#convos'});
  expect(d.status).toBe('success');
  expect(d.startOfHistory).toBe(null);
  expect(socket.queue.length).toBe(2);
  expect(socket.queue[1]).toEqual({id: '2', method: 'send', connection_id: 'irc-freenode', dialog_id: '#convos', message: '/names'});

  d.messagesOp.perform = mockMessagesOpPerform({
    body: {end: true, messages: [{from: 'Supergirl', message: 'Something old', type: 'action', ts: '2020-01-20T09:00:50.001Z'}]},
    status: 200,
  });
  d.update({status: 'pending'});
  await d.load({before: 'maybe'});
  expect(d.messagesOp.performed).toEqual({before: '2020-01-20T09:01:50.001Z', connection_id: 'irc-freenode', dialog_id: '#convos', limit: 60});
  expect(d.status).toBe('success');
  expect(socket.queue.length).toBe(2);

  const messages = d.messages.map(_m => {
    const m = {..._m};
    delete m.color;
    delete m.embeds;
    delete m.from;
    delete m.message;
    delete m.ts;
    return m;
  });

  expect(d.startOfHistory && d.startOfHistory.toISOString()).toBe('2020-01-20T09:00:50.001Z');
  expect(messages).toEqual([
    {fromId: 'supergirl', id: 'msg_3', markdown: 'Something old', type: 'action'},
    {fromId: 'supergirl', id: 'msg_1', markdown: 'Cool beans', type: 'private'},
    {fromId: 'supergirl', id: 'msg_2', markdown: 'Something new', type: 'private'},
  ]);
});

function mockMessagesOpPerform(res) {
  return function(params) {
    this.performed = params;
    this.emit('start', params); // TODO
    this.parse(res);
  };
}
