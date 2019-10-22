import {get, writable} from 'svelte/store';

let baseUrl = location.href.replace(/\/+$/, '');

function indexOrNull(str, searchValue) {
  const i = str.indexOf(searchValue);
  return i == -1 ? null : i;
}

export function historyListener() {
  const handleHistoryChange = () => currentUrl.set(parseUrl(location.href));
  window.addEventListener('popstate', handleHistoryChange);
  return () => window.removeEventListener('popstate', handleHistoryChange);
}

export function gotoUrl(url, params = {}) {
  const nextUrl = parseUrl(url);
  if (!nextUrl) return (location.href = url);
  if (params.event) params.event.preventDefault();
  history[params.replace ? 'replaceState' : 'pushState']({}, document.title, nextUrl.toString());
  setTimeout(() => currentUrl.set(nextUrl), 0);
}

function parseUrl(url) {
  url = url.slice(0, 1) == '/' ? baseUrl + url : url;
  if (url.indexOf(baseUrl) == -1) return false;

  const nextUrl = new URL(url);
  const path = url.substring(baseUrl.length + 1, indexOrNull(url, '?') || indexOrNull(url, '#') || url.length);
  Object.defineProperty(nextUrl, 'path', {value: path, writable: false});

  const pathParts = path.split('/').filter(p => p.length).map(decodeURIComponent);
  Object.defineProperty(nextUrl, 'pathParts', {value: pathParts, writable: false});

  return nextUrl;
}

export function urlToForm(formEl, url = get(currentUrl)) {
  url.searchParams.forEach((val, name) => {
    const inputEl = formEl[name];
    if (!inputEl || !inputEl.tagName) return;

    if (inputEl.type == 'checkbox') {
      inputEl.checked = val ? true : false;
    }
    else {
      inputEl.value = val;
    }

    if (inputEl.syncValue) inputEl.syncValue();
  });
}

export const activeMenu = writable('');
export const container = writable({wideEnough: false, width: 0});
export const currentUrl = writable(parseUrl(location.href));
export const docTitle = writable(document.title);

Object.defineProperty(currentUrl, 'base', {
  get() { return baseUrl },
  set(val) {
    baseUrl = val.replace(/\/+$/, '');
    currentUrl.set(get(currentUrl));
  },
});
