import Route from '../../assets/store/Route';

test('defaults', () => {
  const r = new Route({});

  r._location = {hash: '#foo', href: 'https://demo.convos.chat/chat'};

  expect(r.basePath).toBe('');
  expect(r.baseUrl).toBe('');
  expect(r.hash).toBe('foo');
  expect(r.path).toBe('/');
  expect(r.query).toEqual({});
});

test('baseUrl', () => {
  const r = new Route({});

  r.update({baseUrl: 'https://demo.convos.chat/whatever///'});
  expect(r.baseUrl).toBe('https://demo.convos.chat/whatever');
  expect(r.basePath).toBe('/whatever');
});

test('param', () => {
  const r = new Route({});

  expect(r.param('foo')).toBe('');
  expect(r.param('foo', null)).toBe(null);

  r.query.foo = 'bar';
  expect(r.param('foo')).toBe('bar');
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
