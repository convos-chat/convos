import ConnURL from '../assets/js/ConnURL';

test('ConnURL http', () => {
  const url = new ConnURL('http://convos.by/');
  expect(url.toString()).toBe('http://convos.by/');

  url.href = 'https://convos.by/';
  expect(url.toString()).toBe('https://convos.by/');
});

test('ConnURL irc', () => {
  const url = new ConnURL('irc://irc.example.com/%23convos?nick=supergirl');
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
