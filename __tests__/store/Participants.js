import Participants from '../../assets/store/Participants';

test('basic', () => {
  const participants = new Participants();

  expect(participants.length).toBe(0);
  expect(participants.get('foo')).toBe(undefined);
  expect(participants.has('foo')).toBe(false);
  expect(participants.me()).toEqual({color: '#000000', id: '', modes: {}, nick: ''});
  expect(participants.nicks()).toEqual([]);
  expect(participants.toArray()).toEqual([]);
});

test('add', () => {
  const participants = new Participants();

  participants.add({nick: 'superwoman'});
  expect(participants.length).toBe(1);
  expect(participants.get('superwoman').nick).toBe('superwoman');

  participants.add({nick: 'Superwoman'});
  expect(participants.length).toBe(1);
  expect(participants.get('superwoman').nick).toBe('Superwoman');

  participants.add({nick: 'Superwoman', mode: 'ov'});
  expect(participants.length).toBe(1);
  expect(participants.get('superwoman').modes).toEqual({operator: true, voice: true});

  participants.add({nick: 'Superwoman', mode: 'v'});
  expect(participants.length).toBe(1);
  expect(participants.get('superwoman').modes).toEqual({voice: true});

  participants.add({nick: 'Superwoman', modes: {bar: false, foo: true}});
  expect(participants.length).toBe(1);
  expect(participants.get('superwoman').modes).toEqual({bar: false, foo: true});
});

test('add, rename, delete', () => {
  const participants = new Participants();

  participants.add({nick: 'Superwoman'});
  expect(participants.length).toBe(1);
  expect(participants.nicks()).toEqual(['Superwoman']);

  participants.add({nick: 'superman', me: true});
  expect(participants.length).toBe(2);
  expect(participants.get('superman')).toEqual({color: '#b26b70', id: 'superman', me: true, modes: {}, nick: 'superman'});

  participants.rename('superduper', 'superman');
  expect(participants.length).toBe(2);
  expect(participants.get('superduper')).toBe(undefined);

  participants.rename('SUPERMAN', 'Superduper');
  expect(participants.length).toBe(2);
  expect(participants.get('superduper')).toEqual({color: '#b1b26b', id: 'superduper', me: true, modes: {}, nick: 'Superduper'});

  expect(participants.has('SUPERDUPER')).toBe(true);
  participants.delete('SUPERDUPER');
  expect(participants.get('superduper')).toBe(undefined);
});

test('clear', () => {
  const participants = new Participants();

  participants.add({nick: 'SuperWoman', me: true});
  participants.add({nick: 'superman'});
  expect(participants.me()).toEqual({color: '#8d6bb2', id: 'superwoman', me: true, modes: {}, nick: 'SuperWoman'});

  // Keeping "me" participant on clear
  expect(participants.length).toBe(2);
  expect(participants.clear()).toBe(participants);
  expect(participants.length).toBe(1);
  expect(participants.nicks()).toEqual(['SuperWoman']);
});
