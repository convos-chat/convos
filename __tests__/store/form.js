import {createForm} from '../../assets/store/form';
import {get} from 'svelte/store';

test('field', () => {
  const form = createForm();
  const ageField = form.field('age');
  expect(form.field('age')).toEqual(ageField);
});

test('get', () => {
  const form = createForm({defaultValue: 42});
  const ageField = form.field('age');
  expect(form.get('defaultValue')).toBe('42');
  expect(form.get('age')).toBe('');
  expect(form.get('age')).toBe(get(ageField));
  expect(form.get('foo')).toBe(undefined);
  expect(form.get(['age', 'bar'])).toEqual({age: '', bar: undefined});
  expect(form.get()).toEqual({age: '', defaultValue: '42'});
});

test('set', () => {
  const form = createForm();
  form.set({age: 42});
  expect(form.get('age')).toBe('42');
  expect(form.get('foo')).toBe(undefined);
});

test('get - immutable', () => {
  const form = createForm();
  const ageField = form.field('name');
  const data = form.get();
  expect(data).toEqual({name: ''});

  data.name = 'superman';
  expect(data).toEqual({name: 'superman'});

  form.set({name: 'superwoman'})
  expect(form.get('name')).toBe('superwoman');
  expect(get(ageField)).toBe('superwoman');
  expect(data).toEqual({name: 'superman'});

  const fields = form.get(['name']);
  expect(fields).toEqual({name: 'superwoman'});

  fields.name = 'superduper';
  expect(fields).toEqual({name: 'superduper'});
  expect(form.get(['name'])).toEqual({name: 'superwoman'});
});

test('subscribe', () => {
  const form = createForm();
  const cb = jest.fn();
  form.subscribe(cb);
  expect(cb.mock.calls.pop()).toEqual([{}]);

  form.set({age: 42});
  expect(cb.mock.calls.pop()).toEqual([{age: '42'}]);

  form.set({beans: 'cool'});
  expect(cb.mock.calls.pop()).toEqual([{age: '42', beans: 'cool'}]);

  form.set({agree: false});
  expect(cb.mock.calls.pop()).toEqual([{age: '42', agree: false, beans: 'cool'}]);
});
