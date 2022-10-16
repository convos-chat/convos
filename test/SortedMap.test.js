import SortedMap from '../assets/js/SortedMap';
import {expect, test} from 'vitest';

test('SortedMap', () => {
  const m = new SortedMap();
  expect(m).toBe(m);

  test('set', () => {
    m.set('def', {name: 'def'});
    m.set('abc', {name: 'abc'});
  });

  test('toArray, values', () => {
    expect(m.toArray()).toEqual([{name: 'abc'}, {name: 'def'}]);
  });

  test('filter', () => {
    expect(m.filter(i => i.name == 'def')).toEqual([{name: 'def'}]);
  });

  test('entries', () => {
    const e = m.entries();
    expect(e.next()).toEqual({value: ['abc', {name: 'abc'}], done: false});
    expect(e.next()).toEqual({value: ['def', {name: 'def'}], done: false});
    expect(e.next()).toEqual({value: undefined, done: true});
  });
}); 
