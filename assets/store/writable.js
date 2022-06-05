import {get, writable} from 'svelte/store';

const generated = {};

export function generateWriteable(name, intial = '') {
  if (generated[name]) return generated[name];

  const store = generated[name] = writable(intial);
  store.toggle = (e) => {
    const aEl = e.target.closest('a');
    if (!aEl) return setTimeout(() => store.set(intial), 50);
    e.preventDefault();

    const val = aEl.href.replace(/.*#/, '');
    const loc = location.href.split('#')[0].split('?')[0];
    if (aEl.href.indexOf('#') == 0 || aEl.href.indexOf(loc) == 0) {
      store.set(get(store) == val ? '' : val);
    }
    else {
      setTimeout(() => store.set(val), 100);
    }
  };

  return store;
}
