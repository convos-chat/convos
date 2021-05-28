import Messages from '../../assets/store/Messages';

test('constructor', () => {
  const messages = new Messages();

  expect(messages.length).toBe(0);
  expect(messages.messages).toEqual([]);
  expect(messages.expandUrlToMedia).toBe(true);
  expect(messages.toArray()).toBe(messages.messages);
});

test('clear, get, push, unshift', () => {
  const messages = new Messages();

  expect(messages.get(0)).toBe(undefined);
  expect(messages.get(42)).toBe(undefined);
  expect(messages.get(-1)).toBe(undefined);
  expect(messages.get(-24)).toBe(undefined);

  const base = {
    color: 'inherit',
    from: 'Convos',
    ts: true,
    type: 'notice',
  };

  messages.push([{message: 'a', from: 'superwoman', type: 'private'}]);
  messages.push([{message: 'b', type: 'error'}, {message: 'c'}]);
  messages.push([]);
  expect(messages.length).toBe(3);
  expect(predictable(messages.get(0))).toEqual({...base, color: '#8d6bb2', from: 'superwoman', id: 1, message: 'a', type: 'private'});
  expect(predictable(messages.get(1))).toEqual({...base, id: 2, internal: true, message: 'b', type: 'error'});
  expect(predictable(messages.get(3))).toBe(undefined);

  messages.unshift([]);
  messages.unshift([{message: '1'}]);
  messages.unshift([{message: '2'}, {...base, message: '3'}]);
  expect(messages.length).toBe(6);
  expect(predictable(messages.get(0))).toEqual({...base, id: 5, internal: true, message: '2'});
  expect(predictable(messages.get(5))).toEqual({...base, id: 3, internal: true, message: 'c'});
  expect(predictable(messages.get(6))).toBe(undefined);

  messages.clear();
  expect(messages.length).toBe(0);
});

test('ts', () => {
  const messages = new Messages();

  messages.push([{message: 'a'}, {message: 'b', ts: '2020-02-05T01:02:03Z'}]);
  expect(messages.get(0).ts.toISOString()).toMatch(/^\d+-\d+-\d+T\d+:\d+:\d/);
  expect(messages.get(1).ts.toISOString()).toBe('2020-02-05T01:02:03.000Z');
});

test('render', () => {
  const messages = new Messages();

  messages.push([{from: 'superduper', message: 'a', type: 'action', ts: '2020-02-01T01:02:03Z'}]);
  expect(messages.render().map(predictable)).toEqual([
    {
      className: 'message is-type-action has-not-same-from',
      color: '#b1b26b',
      dayChanged: false,
      embeds: [],
      from: 'superduper',
      id: 9,
      index: 0,
      markdown: 'a',
      message: 'a',
      ts: true,
      type: 'action',
    },
  ]);

  messages.push([{from: 'superduper', message: 'b', type: 'private', ts: '2020-02-05T06:02:03Z'}]);
  expect(predictable(messages.render()[1]).className).toBe('message is-type-private has-not-same-from');
  expect(predictable(messages.render()[1]).dayChanged).toBe(true);

  messages.push([{from: 'superduper', highlight: true, message: 'c', type: 'private', ts: '2020-02-05T07:03:04Z'}]);
  expect(predictable(messages.render()[2]).className).toBe('message is-type-private is-highlighted has-same-from');
  expect(predictable(messages.render()[2]).dayChanged).toBe(false);
});

test('markdown', () => {
  const messages = new Messages();

  messages.push([{from: 'superduper', message: 'Click on [Help](/help)'}]);
  expect(predictable(messages.render()[0]).markdown).toBe('Click on <a href=\"/help\">Help</a>');

  messages.push([{from: 'superduper', message: 'Click on [%1](/logout)', vars: ['Logout']}]);
  expect(predictable(messages.render()[1]).markdown).toBe('Click on <a href=\"/logout\">Logout</a>');
});

test('expandUrlToMedia', () => {
  const messages = new Messages();
  expect(messages.expandUrlToMedia).toBe(true);

  messages.push([{from: 'superduper', message: 'a', type: 'private'}]);
  expect(messages.render()[0].embeds.length).toBe(0);
  expect(messages.get(0).rendered).toBe(undefined);
  expect(messages.render(0)[0].embeds.length).toBe(0);
  expect(messages.get(0).rendered).toBe(true);

  messages.push([{from: 'superduper', message: 'https://convos.chat', type: 'private'}]);
  expect(messages.render(1)[1].embeds.length).toBe(1);
  expect(messages.get(1).rendered).toBe(true);

  expect(messages.update({expandUrlToMedia: false})).toBe(messages);
  expect(messages.get(1).rendered).toBe(undefined);

  expect(messages.render(1)[1].embeds.length).toBe(0);
  expect(messages.render(1)[1].rendered).toBe(true);
}); 

test('details', () => {
  const messages = new Messages();
  messages.push([{from: 'superduper', message: 'a', type: 'private'}]);
  messages.push([{from: 'superduper', message: 'a', type: 'error'}]);
  messages.push([{from: 'superduper', message: 'a', type: 'notice', kicker: 'superwoman'}]);

  // Try render messages outside of the list
  [-1, 0, 1, 2, 3, 4, 5].forEach(i => messages.render(i));

  expect(messages.get(0).details).toBe(null);
  expect(messages.get(1).details).toBe(null);
  expect(messages.get(2).details).toEqual({
    from: 'superduper',
    kicker: 'superwoman',
    message: 'a',
    type: 'notice',
  });
});

function predictable(msg) {
  return msg ? {...msg, ts: msg.ts ? true : false} : undefined;
}
