import {get, writable} from 'svelte/store';

const LOCAL_STORAGE_PREIFX = 'convos:';

export const expandUrlToMedia = localstorage('expandUrlToMedia', true);
export const lastUrl = localstorage('lastUrl', '');

export const getUserInputStore = (id) => {
  return getUserInputStore[id] || (getUserInputStore[id] = localstorage(id + ':userInput', ''));
};

export const rawMessagesStore = (id) => {
  return rawMessagesStore[id] || (rawMessagesStore[id] = localstorage(id + ':raw', false));
};

function localstorage(storageKey, initialValue) {
  storageKey = LOCAL_STORAGE_PREIFX + storageKey;

  const getFromStorage = () => {
    let val = initialValue;
    try {
      if (localStorage.hasOwnProperty(storageKey)) val = JSON.parse(localStorage.getItem(storageKey));
    }
    catch (err) {
      log.error(err);
    }

    return val;
  };

  const store = writable(getFromStorage());
  const set = store.set;

  store.get = () => get(store);
  store.load = () => set(getFromStorage());
  store.set = (val) => {
    val === initialValue ? localStorage.removeItem(storageKey) : localStorage.setItem(storageKey, JSON.stringify(val));
    set(val);
  };

  return store;
}
