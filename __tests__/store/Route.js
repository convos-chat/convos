import Route from '../../assets/store/Route';

test('defaults', () => {
  const r = new Route({});

  expect(r.basePath).toBe('');
  expect(r.baseUrl).toBe('');
  expect(r.canonicalPath).toBe('/');
  expect(r.component).toBe(null);
  expect(r.lastUrl).toBe('');
  expect(r.pathParts).toEqual([]);
  expect(r.query).toEqual({});
});

test('baseUrl', () => {
  const r = new Route({});

  r.update({baseUrl: 'https://demo.convos.by/whatever///'});
  expect(r.baseUrl).toBe('https://demo.convos.by/whatever');
  expect(r.basePath).toBe('/whatever');
});

test('go', () => {
  const r = new Route({});

  let show = [];
  r._page.show = (path, state, ...params) => {
    r.ctx.state = state;
    show = [path, state].concat(params);
  };

  let replace = [];
  r._history = {replaceState: (...params) => (replace = params)};

  r.go('/foo');
  expect(show).toEqual([]);

  r._started = true;
  r.go('/foo');
  expect(show).toEqual(['/foo', {}, true, true]);

  r.go('https://demo.convos.by');
  expect(show).toEqual(['https://demo.convos.by', {}, true, true]);

  r.update({baseUrl: 'https://demo.convos.by/whatever///'});
  r.go('https://demo.convos.by/whatever/foo');
  expect(show).toEqual(['/foo', {}, true, true]);

  r.go('/whatever/foo', {too: 'cool'});
  expect(show).toEqual(['/foo', {too: 'cool'}, true, true]);

  r.go('/whatever/replace', null, true);
  expect(replace).toEqual([{too: 'cool'}, '', '/whatever/replace']);
  expect(show).toEqual(['/replace', {too: 'cool'}, true, false]);

  r.go('/replace/cooler', {too: 'cooler'}, true);
  expect(replace).toEqual([{too: 'cooler'}, '', '/whatever/replace/cooler']);
  expect(show).toEqual(['/replace/cooler', {too: 'cooler'}, true, false]);
});

test('param', () => {
  const r = new Route({});

  expect(r.param('foo')).toBe('');
  expect(r.param('foo', null)).toBe(null);

  r.query.foo = 'bar';
  expect(r.param('foo')).toBe('bar');

  r.ctx.params.foo = 'foo';
  expect(r.param('foo')).toBe('foo');
});

test('urlFor', () => {
  const r = new Route({});
  expect(r.urlFor('/foo')).toBe('/foo');

  r.update({baseUrl: 'https://demo.convos.by/whatever///'});
  expect(r.urlFor('/foo')).toBe('/whatever/foo');
  expect(r.urlFor('https://convos.by/blog/')).toBe('https://convos.by/blog/');
  expect(r.urlFor('#hash')).toBe('#hash');
});
