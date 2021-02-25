import {get} from 'svelte/store';
import {formAction, makeFormStore} from '../../assets/store/form';

test('formAction', () => {
  const formStore = makeFormStore();
  const formEl = document.createElement('form');

  const rendered = []
  formStore.render = (fields) => rendered.push(fields);

  const action = formAction(formEl, formStore);
  expect(rendered).toEqual([undefined]);
});

test('formAction change', () => {
  const formStore = makeFormStore();
  const formEl = document.createElement('form');
  const action = formAction(formEl, formStore);

  const inputEl = document.createElement('input');
  inputEl.type = 'checkbox';
  inputEl.name = 'accept';
  inputEl.value = 'accepted';
  formEl.appendChild(inputEl);
  inputEl.dispatchEvent(new Event('change', {bubbles: true, cancelable: true}));
  expect(get(formStore)).toEqual({accept: undefined});

  inputEl.checked = true;
  inputEl.dispatchEvent(new Event('change', {bubbles: true, cancelable: true}));
  expect(get(formStore)).toEqual({accept: 'accepted'});
});

test('formAction submit', () => {
  const formStore = makeFormStore();
  const formEl = document.createElement('form');
  const action = formAction(formEl, formStore);

  let submit = [];
  formStore.submit = (el) => submit.push(formStore.formEl);
  formEl.dispatchEvent(new Event('submit'));
  expect(submit).toEqual([formEl]);
});

test('makeFormStore', () => {
  const formStore = makeFormStore();
  expect(get(formStore)).toEqual({});
});

test('render', () => {
  const formStore = makeFormStore();
  expect(formStore.render()).toBe(null);

  formStore.formEl = document.createElement('form');
  expect(formStore.render()).toEqual([]);

  const nickEl = document.createElement('input');
  formStore.formEl.appendChild(nickEl);
  formStore.set({nick: 'superman'});
  expect(formStore.render()).toEqual([null]);

  nickEl.name = 'nick';
  expect(formStore.render()).toEqual(['nick']);
  expect(nickEl.value).toBe('superman');

  expect(formStore.render({nick: 'superwoman'})).toEqual(['nick']);
  expect(nickEl.value).toBe('superwoman');

  const acceptEl = document.createElement('input');
  acceptEl.type = 'checkbox';
  acceptEl.name = 'accept';
  acceptEl.value = 'accepted';
  formStore.formEl.appendChild(acceptEl);
  expect(formStore.render({accept: false})).toEqual(['accept']);
  expect(acceptEl.value).toBe('accepted');
  expect(acceptEl.checked).toBe(false);

  expect(formStore.render({accept: true})).toEqual(['accept']);
  expect(acceptEl.value).toBe('accepted');
  expect(acceptEl.checked).toBe(true);

  // Unchanged
  expect(nickEl.value).toBe('superwoman');
});

test('renderOnNextTick', async () => {
  const formStore = makeFormStore();
  const p = new Promise(resolve => { formStore.render = resolve });

  formStore.renderOnNextTick({foo: 42});
  expect(await p).toEqual({foo: 42});
});
