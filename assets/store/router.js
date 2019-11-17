import {derived, get, writable} from 'svelte/store';
import {replaceClassName} from '../js/util';

let baseUrl = location.href.replace(/\/+$/, '');
let calculateCurrentPageComponentLock = '';

export const activeMenu = writable('');
export const container = writable({wideScreen: false, width: 0});
export const currentUrl = writable(parseUrl(location.href));
export const docTitle = writable(document.title);
export const pageComponent = writable(null);

export function calculateCurrentPageComponent($currentUrl, $user, routingRules) {
  const path = $currentUrl.path;
  const lock = [$user.status, path].join(':');
  if (lock == calculateCurrentPageComponentLock) return;

  for (let i = 0; i < routingRules.length; i++) {
    const [routeRe, component, options] = routingRules[i];
    if (!routeRe.test(path)) continue;

    // Check matching route rules
    if (options.user && !$user.is(options.user)) continue; // Not ready yet
    if (options.gotoLast) return gotoUrl($user.calculateLastUrl());

    // Render matching route
    switchPageComponent(component);
    replaceClassName('body', /(is-logged-)\S+/, $user.is('loggedIn') ? 'in' : 'out');
    replaceClassName('body', /(page-)\S+/, options.name || $currentUrl.pathParts[0]);

    if (options.user == 'loggedIn') $user.update({lastUrl: $currentUrl.toString()});
    break;
  }

  calculateCurrentPageComponentLock = lock;
}

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
  if (url === null) return;
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
  const path = url.substring(baseUrl.length, indexOrNull(url, '?') || indexOrNull(url, '#') || url.length);
  Object.defineProperty(nextUrl, 'path', {value: path, writable: false});

  const pathParts = path.split('/').filter(p => p.length).map(decodeURIComponent);
  Object.defineProperty(nextUrl, 'pathParts', {value: pathParts, writable: false});

  return nextUrl;
}

export async function redirectAfterLogin(user, op) {
  document.cookie = op.res.headers['Set-Cookie'];
  op.reset();
  await user.load();
  gotoUrl(user.calculateLastUrl());
}

function switchPageComponent(nextPageComponent) {
  // Only switch if the page has actually changed
  const currentPageComponent = get(pageComponent);
  if (nextPageComponent == currentPageComponent) return;

  // Remove original components before doing the switch
  if (!currentPageComponent) {
    const removeEls = document.querySelectorAll('.js-remove');
    for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();
  }

  // Switch the page
  pageComponent.set(nextPageComponent);
}

export function urlFor(path) {
  return currentUrl.base + path;
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

Object.defineProperty(currentUrl, 'base', {
  get() { return baseUrl },
  set(val) {
    baseUrl = val.replace(/\/+$/, '');
    currentUrl.set(parseUrl(get(currentUrl).toString()));
  },
});
