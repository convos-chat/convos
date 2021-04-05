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

test('toFields', () => {
  const url = new ConnectionURL('irc://irc.example.com/');

  expect(url.toFields()).toEqual({
    conversation_id: '',
    host: 'irc.example.com',
    nick: '',
    password: '',
    protocol: 'irc:',
    realname: '',
    sasl: 'none',
    tls: false,
    tls_verify: false,
    username: '',
  });
});

test('fromFields, toFields', () => {
  const url = new ConnectionURL('irc://0:0@convos.chat:6697/%23convos?sasl=cool&nick=Super&realname=Clark&tls=1&tls_verify=0');

  expect(url.toFields()).toEqual({
    conversation_id: '#convos',
    host: 'convos.chat:6697',
    nick: 'Super',
    password: '0',
    protocol: 'irc:',
    realname: 'Clark',
    sasl: 'cool',
    tls: true,
    tls_verify: false,
    username: '0',
  });

  expect(new ConnectionURL().fromFields(url.toFields()).toString())
    .toBe('irc://0:0@convos.chat:6697/%23convos?nick=Super&realname=Clark&sasl=cool&tls=1&tls_verify=0');
});
