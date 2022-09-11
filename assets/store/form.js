import {getLogger} from '../js/logger';
import {is} from '../js/util';
import {writable} from 'svelte/store';

const log = getLogger('form');

function get(data, names) {
  if (is.undefined(names)) names = Object.keys(data);
  return is.array(names) ? names.reduce((map, name) => { map[name] = data[name]; return map }, {}) : data[names];
}

function load(form, formEl, fields) {
  for (const name in fields) {
    const input = formEl[name];
    if (input) fields[name].set(input.value);
  }
  return form;
}

function set(form, to) {
  Object.keys(to).forEach(name => form.field(name).set(is.stringable(to[name]) ? String(to[name]) : to[name]));
  return form;
}

function subscribe(subscribers, cb) {
  const subscriber = [cb]; // Make sure each element is unique
  subscribers.push(subscriber);
  return () => {
    const index = subscribers.indexOf(subscriber);
    if (index != -1) subscribers.splice(index, 1);
  };
}

/**
 * createForm() is used to create a form object that makes it easy to
 * synchronize form values.
 *
 * @example
 * const form = createForm();
 * form.set({agree: false, foo: 'bar'});           // == form
 * const agreeField = form.field('agree');         // svelte/store "writable" object
 * agreeField.set(true);
 * form.subscribe(fields => { ... });
 *
 * const fieldValue = form.get('agree');           // == true
 * const allFieldValues = form.get();              // == {agree: true, foo: 'bar'}
 * const someFieldValuesMap = form.get(['agree']); // == {agree: true}
 *
 * @returns {Object} A reactive form store
 */
export const createForm = (defaultFields = {}) => {
  const data = {};
  const fields = {};
  const form = {};
  const subscribers = [];

  form.field = (name) => {
    if (fields[name]) return fields[name];

    const field = writable('');
    field.subscribe((val) => {
      log.debug(name, '=', val);
      data[name] = val;
      for (const subscriber of subscribers) subscriber[0](data);
    });

    return (fields[name] = field);
  };

  form.remove = (names) => {
    names.forEach(name => (delete data[name], delete fields[name], delete subscribers[name]));
    for (const subscriber of subscribers) subscriber[0](data);
  };

  form.get = (names) => get(data, names);
  form.load = (formEl) => load(form, formEl, fields);
  form.set = (to) => set(form, to);
  form.subscribe = (cb) => { cb(data); return subscribe(subscribers, cb) };
  Object.keys(defaultFields).forEach(k => form.set({[k]: defaultFields[k]}));

  return form;
};
