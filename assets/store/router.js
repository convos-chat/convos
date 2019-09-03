import {derived, writable} from 'svelte/store';

function handleHistoryChange(e) {
  hrefToPathname(location.href);
}

export function historyListener() {
  window.addEventListener('popstate', handleHistoryChange);
  return () => window.removeEventListener('popstate', handleHistoryChange);
}

export function gotoUrl(url, params = {}) {
  if (hrefToPathname(url) === null) return (location.href = url);
  history[params.replace ? 'replaceState' : 'pushState']({}, document.title, url);
}

export function hrefToPathname(href) {
  const pathnameStart = href.indexOf('/') == 0 ? 0 : href.indexOf(baseUrl) + baseUrl.length;
  const pathnameStop = href.indexOf('#') == -1 ? href.length : href.indexOf('#');
  if (pathnameStart == baseUrl.length - 1) return null;
  const val = href.substring(pathnameStart, pathnameStop);
  fragment.set(href.substring(pathnameStop + 1));
  pathname.set(val);
  return val;
}

export const baseUrl = '//' + location.host; // TODO: Add support for example.com/whatever/convos/
export const fragment = writable(location.hash.substring(1));
export const pathname = writable(location.pathname);

export const pathParts = derived(pathname, ($pathname) => {
  return $pathname.split('/').filter(p => p.length).map(decodeURIComponent);
});

export const queryString = writable(location.search);
