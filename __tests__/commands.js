import {commandOptions, commands, normalizeCommand} from '../assets/js/commands';

test('commands', () => {
  expect(commands.length > 15).toBe(true);
  commands.forEach(cmd => expect(Object.keys(cmd).sort()).toEqual(['cmd', 'description', 'example']));
});

test('commandOptions', () => {
  expect(commandOptions({query: '/'}).length).toBe(commands.length);
  expect(commandOptions({query: '/join'})).toEqual([{text: '/join &lt;<a href=\"./%23channel\">#channel</a>&gt;', val: '/join'}]);
});

test('normalizeCommand', () => {
  expect(normalizeCommand('/CLOSE')).toBe('/part');
  expect(normalizeCommand('/cs cool beans')).toBe('/quote chanserv cool beans');
  expect(normalizeCommand('/j #foo pass')).toBe('/join #foo pass');
  expect(normalizeCommand('/j')).toBe('/join');
  expect(normalizeCommand('/ns cool beans')).toBe('/quote nickserv cool beans');
  expect(normalizeCommand('/raw YIKES')).toBe('/quote YIKES');
  expect(normalizeCommand('/shrug')).toBe('/say ¯\\_(ツ)_/¯');
  expect(normalizeCommand('/shrug not sure')).toBe('/say not sure ¯\\_(ツ)_/¯');
});
