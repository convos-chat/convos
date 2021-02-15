import Route from '../../assets/store/Route';

test('defaults', () => {
  const r = new Route({});

  r._location = {hash: '#foo', href: 'https://demo.convos.chat/chat'};

  expect(r.basePath).toBe('');
  expect(r.baseUrl).toBe('');
  expect(r.component).toBe(null);
  expect(r.hash).toBe('foo');
  expect(r.params).toEqual({});
  expect(r.path).toBe('/');
  expect(r.query).toEqual({});
  expect(r.requireLogin).toBe(false);
  expect(r.state).toEqual({});
  expect(r.title).toBe('');
});

test('baseUrl', () => {
  const r = new Route({});

  r.update({baseUrl: 'https://demo.convos.chat/whatever///'});
  expect(r.baseUrl).toBe('https://demo.convos.chat/whatever');
  expect(r.basePath).toBe('/whatever');
});

test('routing', () => {
  const r = new Route({});
  r.update({baseUrl: 'https://demo.convos.chat///'});

  let matched = [];
  const history = mockHistory(r);
  const cb = (route) => matched.push({...route.params, ...route.query, hash: route.hash});

  r.to('/chat/:connection_id', cb);
  r.to('/chat/:connection_id/:conversation_id', cb);
  r.to('/help', cb);
  r.to('*', cb);

  expect(r._routes).toEqual([
    {re: /^\/chat\/([^/]+)$/, names: ['connection_id'], path: '/chat/:connection_id', cb},
    {re: /^\/chat\/([^/]+)\/([^/]+)$/, names: ['connection_id', 'conversation_id'], path: '/chat/:connection_id/:conversation_id', cb},
    {re: /^\/help$/, names: [], path: '/help', cb},
    {re: /^(.*)$/, names: ['0'], path: '*', cb},
  ]);

  r.go('/?x=2&y=3#0');
  expect(r.path).toBe('/');
  r.go('/chat/irc-foo?ts=2020');
  expect(r.path).toBe('/chat/irc-foo');

  r.update({title: 'cool beans'});
  r.go('/chat/irc-foo/%23x%2Fbar#cool_beans');
  expect(r.path).toBe('/chat/irc-foo/%23x%2Fbar');
  r.go('https://demo.convos.chat/not/found');
  r.go('https://demo.convos.chat/not/found'); // noop
  expect(r.path).toBe('/not/found');

  r.update({baseUrl: 'https://demo.convos.chat/whatever/', title: 'abs'});
  r.go('/help', {foo: 'bar'}, true);
  expect(r.path).toBe('/help');

  expect(matched).toEqual([
    {hash: '0', '0': '/', x: '2', y: '3'},
    {hash: '', connection_id: 'irc-foo', ts: '2020'},
    {hash: 'cool_beans', connection_id: 'irc-foo', conversation_id: '#x/bar'},
    {hash: '', '0': '/not/found'},
    {hash: '', },
  ]);

  expect(history).toEqual([
    ['pushState', {}, '', 'https://demo.convos.chat/?x=2&y=3#0'],
    ['pushState', {}, '', 'https://demo.convos.chat/chat/irc-foo?ts=2020'],
    ['pushState', {}, 'cool beans', 'https://demo.convos.chat/chat/irc-foo/%23x%2Fbar#cool_beans'],
    ['pushState', {}, 'cool beans', 'https://demo.convos.chat/not/found'],
    ['replaceState', {foo: 'bar'}, 'abs', 'https://demo.convos.chat/whatever/help'],
  ]);
});

test('convos.internal', () => {
  const r = new Route({}).update({baseUrl: 'https://convos.internal/'});
  const history = mockHistory(r);

  let registered = 0;
  r.to('/register', () => registered++);
  r.go('/register?email=test%40internal&exp=1594263232&token=abc', {}, false);
  r.go('https://convos.internal/register?email=test%40internal&exp=1594263232&token=def', {}, false);

  expect(registered).toBe(2);
});

test('param', () => {
  const r = new Route({});

  expect(r.param('foo')).toBe('');
  expect(r.param('foo', null)).toBe(null);

  r.query.foo = 'bar';
  expect(r.param('foo')).toBe('bar');

  r.params.foo = 'foo';
  expect(r.param('foo')).toBe('foo');
});

test('urlFor', () => {
  const r = new Route({});
  expect(r.urlFor('/foo')).toBe('/foo');

  r.update({baseUrl: 'https://demo.convos.chat/whatever///'});
  expect(r.urlFor('/foo')).toBe('/whatever/foo');
  expect(r.urlFor('https://convos.chat/blog/')).toBe('https://convos.chat/blog/');
  expect(r.urlFor('#hash')).toBe('#hash');
  expect(r.urlFor('/bar', {n: null, u: undefined, y: 24, x: '4 2'})).toBe('/whatever/bar?x=4%202&y=24');
});

function mockHistory(r) {
  const history = [];
  const hist = (name) => {
    return (...params) => {
      history.push([name, ...params]);
      r._location.href = params.pop();
      r._location.hash = (r._location.href.match(/#(.+)/) || ['', ''])[1];
    };
  };

  r._history = {pushState: hist('pushState'), replaceState: hist('replaceState')};
  r._location = {href: ''};

  return history;
}
