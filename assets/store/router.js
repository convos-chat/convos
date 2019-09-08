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
  if (!parseUrl(url)) return (location.href = url);
  if (params.event) params.event.preventDefault();
  history[params.replace ? 'replaceState' : 'pushState']({}, document.title, url);
  currentUrl.set(new URL(location.href));
}

function parseUrl(href) {
  const pathnameStart = href.indexOf('/') == 0 ? 0 : href.indexOf(baseUrl) + baseUrl.length;
  const hashPos = indexOfNull(href, '#');
  const queryPos = indexOfNull(href, '?');
  if (pathnameStart == baseUrl.length - 1) return false;
  const pathpart = href.substring(pathnameStart, queryPos || hashPos || href.length);
  pathname.set(pathpart);
  return true;
}

export function urlToForm(formEl, url = get(currentUrl)) {
  url.searchParams.forEach((val, name) => {
    const inputEl = formEl[name];
    if (!(inputEl && inputEl.tagName)) {
      return;
    }
    else if (inputEl.type == 'checkbox') {
      inputEl.checked = val ? true : false;
    }
    else {
      formEl[name].value = val;
    }
  });
}

export const baseUrl = '//' + location.host; // TODO: Add support for example.com/whatever/convos/
export const pathname = writable(location.pathname);
export const showMenu = writable(false);

export const pathParts = derived(pathname, ($pathname) => {
  return $pathname.split('/').filter(p => p.length).map(decodeURIComponent);
});

export const currentUrl = writable(new URL(location.href));
