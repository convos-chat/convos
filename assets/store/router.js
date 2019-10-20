import {derived, get, writable} from 'svelte/store';

function indexOfNull(str, searchValue) {
  const i = str.indexOf(searchValue);
  return i == -1 ? null : i;
}

function handleHistoryChange(e) {
  parseUrl(location.href);
  currentUrl.set(new URL(location.href));
}

export function historyListener() {
  window.addEventListener('popstate', handleHistoryChange);
  return () => window.removeEventListener('popstate', handleHistoryChange);
}

export function gotoUrl(url, params = {}) {
  if (url.slice(0, 1) == '/') url = get(baseUrl).replace(/\/+$/, '') + url;
  if (!parseUrl(url)) return (location.href = url);
  if (params.event) params.event.preventDefault();
  history[params.replace ? 'replaceState' : 'pushState']({}, document.title, url);
  currentUrl.set(new URL(location.href));
}

function parseUrl(url) {
  const $baseUrl = get(baseUrl);
  const pathnameStart = url.indexOf('/') == 0 ? 0 : url.indexOf($baseUrl) + $baseUrl.length;
  const hashPos = indexOfNull(url, '#');
  const queryPos = indexOfNull(url, '?');
  if (pathnameStart == $baseUrl.length - 1) return false;
  const pathpart = url.substring(pathnameStart, queryPos || hashPos || url.length);
  setTimeout(() => pathname.set(pathpart), 0);
  return true;
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
export const baseUrl = writable('//' + location.host);
export const docTitle = writable(document.title);
export const pathname = writable(location.pathname);

export const pathParts = derived(pathname, ($pathname) => {
  return $pathname.split('/').filter(p => p.length).map(decodeURIComponent);
});

export const currentUrl = writable(new URL(location.href));
