import * as svelteStore from 'svelte/store';

export function writable(val, methods) {
  const store = svelteStore.writable(val);
  store.get = () => svelteStore.get(store);

  for (let name in methods) {
    if (methods.hasOwnProperty(name)) store[name] = methods[name].bind(store);
  }

  return store;
}
