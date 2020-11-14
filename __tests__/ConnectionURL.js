import ConnectionURL from '../assets/js/ConnectionURL';

test('ConnectionURL http', () => {
  const url = new ConnectionURL('http://convos.chat/');
  expect(url.toString()).toBe('http://convos.chat/');

  url.href = 'https://convos.chat/';
  expect(url.toString()).toBe('https://convos.chat/');
});

test('ConnectionURL irc', () => {
  const url = new ConnectionURL('irc://irc.example.com/%23convos?nick=supergirl');
  expect(url.toString()).toBe('irc://irc.example.com/%23convos?nick=supergirl');

  url.href = 'irc://irc.example.com:6667/%23convos?nick=superduper';
  expect(url.toString()).toBe('irc://irc.example.com:6667/%23convos?nick=superduper');

  url.searchParams.delete('nick');
  expect(url.toString()).toBe('irc://irc.example.com:6667/%23convos');
  expect(url.host).toBe('irc.example.com:6667');
  expect(url.pathname).toBe('/%23convos');

  url.href = 'irc://x:y@irc.example.com:6667';
  expect(url.username).toBe('x');
  expect(url.password).toBe('y');
});
