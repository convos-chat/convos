import {get, writable} from 'svelte/store';

const generated = {};

export const activeMenu = generateWriteable('menu');
export const nColumns = writable(1);

export function generateWriteable(name) {
  if (generated[name]) return generated[name];

  const store = generated[name] = writable('');
  store.toggle = (e) => {
    const aEl = e.target.closest('a');
    if (!aEl) return setTimeout(() => store.set(''), 50);
    e.preventDefault();
    const val = aEl.href.replace(/.*#/, '');
    store.set(get(store) == val ? '' : val);
  };

  return store;
}
