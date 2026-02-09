const APP_MODE = '{{.Mode}}';
const CACHE_NAME = 'convos-{{.Version}}';
const BASE_PATH = '{{.BasePath}}';

const CACHE_FUNCTIONS = {};
const STRATEGY_BYPASS = 'bypass';
const STRATEGY_CACHE_FIRST = '{{.CacheFirst}}';
const STRATEGY_NETWORK_FIRST = 'network_first';
const STRATEGY_PAGE = 'page';
const STRATEGY_DEFAULT = 'default';

const CACHE_RULES = [
  [new RegExp('^' + BASE_PATH + 'api/embed\\.json'), STRATEGY_CACHE_FIRST],
  [new RegExp('^' + BASE_PATH + 'api/'), STRATEGY_BYPASS],
  [new RegExp('^' + BASE_PATH + 'api$'), STRATEGY_NETWORK_FIRST],
  [new RegExp('\\.development\\.(css|js)$'), STRATEGY_NETWORK_FIRST],
  [new RegExp('^' + BASE_PATH + 'themes/'), STRATEGY_NETWORK_FIRST],
  [new RegExp('^' + BASE_PATH + 'asset/'), STRATEGY_CACHE_FIRST],
  [new RegExp('^' + BASE_PATH + 'images/'), STRATEGY_CACHE_FIRST],
  [new RegExp('^' + BASE_PATH + 'font/'), STRATEGY_CACHE_FIRST],
  [new RegExp('^' + BASE_PATH + '?$'), STRATEGY_NETWORK_FIRST],
  [new RegExp('/[^.]+$'), STRATEGY_PAGE],
];

self.addEventListener('install', event => {
  const preCache = ['{{.BasePath}}'];
  self.skipWaiting();
  openCache().then(cache => cache.addAll(preCache));
});

self.addEventListener('activate', event => {
  caches.keys().then(cacheNames => Promise.all(cacheNames.map(cacheName => {
    return cacheName != CACHE_NAME && caches.delete(cacheName);
  })));
});

self.addEventListener('fetch', event => {
  if (event.request.url.indexOf('/sw/info') != -1) return event.respondWith(serviceWorkerInfo());
  const cacheStrategy = calculateCacheStrategy(event);
  const cacheFunction = CACHE_FUNCTIONS[cacheStrategy];
  if (cacheFunction) event.respondWith(openCache().then(cache => cacheFunction(event, cache)));
});

function calculateCacheStrategy(event) {
  const url = new URL(event.request.url);
  if (url.origin == location.origin) {
    for (let i = 0; i < CACHE_RULES.length; i++) {
      if (!CACHE_RULES[i][0].test(url.pathname)) continue;
      return CACHE_RULES[i][1];
    }
  }
  return STRATEGY_DEFAULT;
}

function fetchAndCache(event, cache) {
  return fetch(event.request).then(response => {
    cache.put(event.request, response.clone());
    return response;
  });
}

function openCache() {
  return caches.open(CACHE_NAME);
}

async function serviceWorkerInfo() {
  const info = {mode: APP_MODE, version: '{{.Version}}'};
  return new Response(new Blob([JSON.stringify(info)]));
}

CACHE_FUNCTIONS[STRATEGY_CACHE_FIRST] = function(event, cache) {
  return cache.match(event.request).then(cachedResponse => {
    return cachedResponse || fetchAndCache(event, cache);
  });
};

CACHE_FUNCTIONS[STRATEGY_DEFAULT] = function(event, cache) {
  return fetch(event.request).catch(() => {
    return cache.match(event.request);
  });
};

CACHE_FUNCTIONS[STRATEGY_NETWORK_FIRST] = function(event, cache) {
  return fetchAndCache(event, cache).catch(() => {
    return cache.match(event.request);
  });
};

CACHE_FUNCTIONS[STRATEGY_PAGE] = function(event, cache) {
  return fetch(event.request).catch(() => {
    return cache.match(event.request);
  }).then(cachedResponse => {
    return cachedResponse || cache.match('/');
  });
};
