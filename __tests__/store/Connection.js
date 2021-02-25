import Connection from '../../assets/store/Connection';
import ConnectionURL from '../../assets/js/ConnectionURL';

test('toForm', () => {
  const c = new Connection({});

  expect(c.toForm()).toEqual({
    local_address: '',
    nick: 'guest',
    on_connect_commands: '',
    password: '',
    realname: '',
    sasl: 'none',
    server: 'localhost',
    tls: false,
    tls_verify: false,
    username: '',
    wanted_state: 'connected',
  });

  const url = new ConnectionURL('irc://superwoman:s3cret@irc.example.com:6667/?local_address=1.1.1.1&nick=superwoman&realname=Super+Duper&sasl=external&tls=1&tls_verify=1');
  c.update({url, on_connect_commands: ['cool', 'beans']});

  expect(c.toForm()).toEqual({
    local_address: '1.1.1.1',
    nick: 'superwoman',
    on_connect_commands: 'cool\nbeans',
    password: 's3cret',
    realname: 'Super Duper',
    sasl: 'external',
    server: 'irc.example.com:6667',
    tls: true,
    tls_verify: true,
    username: 'superwoman',
    wanted_state: 'connected',
  });
});

test('toSaveOperationParams create', () => {
  const c = new Connection({});

  expect(c.toSaveOperationParams({
    local_address: '1.1.1.1',
    nick: 'superwoman',
    on_connect_commands: 'cool\n\rbeans',
    password: 's3cret',
    realname: 'Super Duper',
    server: 'irc.example.com:6667',
    tls: true,
    tls_verify: true,
    username: 'superwoman',
    wanted_state: 'connected',
  })).toEqual({
    url: 'irc://superwoman:s3cret@irc.example.com:6667/?local_address=1.1.1.1&nick=superwoman&realname=Super+Duper&sasl=none&tls=1&tls_verify=1',
    on_connect_commands: ['cool', 'beans'],
    wanted_state: 'connected',
  });
});

test('toSaveOperationParams update', () => {
  const c = new Connection({connection_id: 'irc-example'});

  expect(c.toSaveOperationParams({
    nick: 'superwoman',
    password: 's3cret',
    realname: '',
    server: 'irc.example.com:6667',
    tls: true,
    tls_verify: false,
    wanted_state: 'disconnected',
  })).toEqual({
    connection_id: 'irc-example',
    url: 'irc://:s3cret@irc.example.com:6667/?nick=superwoman&sasl=none&tls=1&tls_verify=0',
    on_connect_commands: [],
    wanted_state: 'disconnected',
  });
});
