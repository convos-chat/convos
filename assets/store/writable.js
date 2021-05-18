import {get, writable} from 'svelte/store';

const generated = {};

export const activeMenu = generateWriteable('menu');
export const viewport = writable({nColumns: 1, width: 0});

export function generateWriteable(name, intial = '') {
  if (generated[name]) return generated[name];

  const store = generated[name] = writable(intial);
  store.toggle = (e) => {
    const aEl = e.target.closest('a');
    if (!aEl) return setTimeout(() => store.set(intial), 50);
    e.preventDefault();

    const val = aEl.href.replace(/.*#/, '');
    if (aEl.href.indexOf('#') == 0 || aEl.href.indexOf(location.href) == 0) {
      store.set(get(store) == val ? '' : val);
    }
    else {
      setTimeout(() => store.set(val), 100);
    }
  };

  return store;
}
