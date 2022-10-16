import Search from '../../assets/store/Search';

test('constructor', () => {
  let c = new Search({});
  expect(c.connection_id).toBe('');
  expect(c.conversation_id).toBe('search');
  expect(c.name).toBe('Search');
  expect(c.query).toBe('');
  expect(c.status).toBe('success');
  expect(c.unread).toBe(0);
});

test('is', () => {
  let c = new Search({});

  expect(c.is('conversation')).toBe(false);
  expect(c.is('search')).toBe(true);
});

test('load', async () => {
  let c = new Search({});

  expect(c.markAsReadOp).toBe(null);
  expect(c.messagesOp.id).toBe('searchMessages');
  expect(c.messages.length).toBe(0);

  await c.load();
  expect(c.messages.length).toBe(1);

  c.messagesOp.perform = function() {
    this.res.body = {messages: [{message: 'foo bar'}, {message: 'foo bar baz'}]};
    this.update({status: 'success'});
  };

  const p = c.load({message: 'foo'});
  expect(c.status).toBe('loading');
  await p;
  expect(c.status).toBe('success');
  expect(c.messages.length).toBe(2);
});

test('send', async () => {
  let c = new Search({});

  let sent;
  c.on('send', params => (sent = params));
  expect(await c.send('foo bar')).toEqual({message: 'foo bar'});
  expect(sent).toEqual({message: 'foo bar'});
});

