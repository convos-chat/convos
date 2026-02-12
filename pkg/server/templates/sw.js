const APP_MODE = "{{.Mode}}";
const CACHE_NAME = "convos-{{.Version}}";
const BASE_PATH = "{{.BasePath}}";

const STRATEGY_BYPASS = "bypass";
const STRATEGY_CACHE_FIRST = "{{.CacheFirst}}";
const STRATEGY_NETWORK_FIRST = "network_first";
const STRATEGY_PAGE = "page";
const STRATEGY_DEFAULT = "default";

const CACHE_RULES = [
  [new RegExp("^" + BASE_PATH + "api/embed\\.json"), STRATEGY_CACHE_FIRST],
  [new RegExp("^" + BASE_PATH + "api/"), STRATEGY_BYPASS],
  [new RegExp("^" + BASE_PATH + "api$"), STRATEGY_NETWORK_FIRST],
  [new RegExp("\\.development\\.(css|js)$"), STRATEGY_NETWORK_FIRST],
  [new RegExp("^" + BASE_PATH + "themes/"), STRATEGY_NETWORK_FIRST],
  [new RegExp("^" + BASE_PATH + "assets/"), STRATEGY_CACHE_FIRST],
  [new RegExp("^" + BASE_PATH + "images/"), STRATEGY_CACHE_FIRST],
  [new RegExp("^" + BASE_PATH + "font/"), STRATEGY_CACHE_FIRST],
  [new RegExp("^" + BASE_PATH + "?$"), STRATEGY_NETWORK_FIRST],
  [new RegExp("/[^.]+$"), STRATEGY_PAGE],
];

const CACHE_FUNCTIONS = {
  [STRATEGY_CACHE_FIRST]: async (event, cache) => {
    const cachedResponse = await cache.match(event.request);
    return cachedResponse || fetchAndCache(event, cache);
  },
  [STRATEGY_DEFAULT]: async (event, cache) => {
    try {
      return await fetch(event.request);
    } catch (err) {
      return cache.match(event.request);
    }
  },
  [STRATEGY_NETWORK_FIRST]: async (event, cache) => {
    try {
      return await fetchAndCache(event, cache);
    } catch (err) {
      return cache.match(event.request);
    }
  },
  [STRATEGY_PAGE]: async (event, cache) => {
    try {
      return await fetch(event.request);
    } catch (err) {
      const cachedResponse = await cache.match(event.request);
      return cachedResponse || cache.match("/");
    }
  },
};

self.addEventListener("install", (event) => {
  const preCache = ["{{.BasePath}}"];
  self.skipWaiting();
  event.waitUntil(openCache().then((cache) => cache.addAll(preCache)));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) =>
      Promise.all(
        cacheNames.map((cacheName) => {
          return cacheName !== CACHE_NAME && caches.delete(cacheName);
        }),
      ),
    ),
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.url.includes("/sw/info")) {
    return event.respondWith(serviceWorkerInfo());
  }

  const cacheStrategy = calculateCacheStrategy(event);
  const cacheFunction = CACHE_FUNCTIONS[cacheStrategy];
  if (cacheFunction) {
    event.respondWith(openCache().then((cache) => cacheFunction(event, cache)));
  }
});

self.addEventListener("push", (event) => {
  if (!event.data) return;

  const promise = clients
    .matchAll({ type: "window", includeUncontrolled: true })
    .then((windowClients) => {
      if (windowClients.some((c) => c.focused)) return;

      const payload = event.data.json();
      const title = payload.title || "New message";
      const options = {
        body: payload.body || "",
        icon: payload.icon || "/assets/apple-touch-icon-192x192.png",
        badge: payload.badge || "/assets/apple-touch-icon-72x72.png",
        tag: payload.tag || "convos",
        data: payload.data || {},
      };

      return self.registration.showNotification(title, options);
    });

  event.waitUntil(promise);
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const urlToOpen = new URL(event.notification.data.url || "/", self.location.origin).href;

  const promise = clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
    let matchingClient = null;

    for (const windowClient of windowClients) {
      if (windowClient.url === urlToOpen) {
        matchingClient = windowClient;
        break;
      }
    }

    if (matchingClient) {
      return matchingClient.focus();
    } else {
      return clients.openWindow(urlToOpen);
    }
  });

  event.waitUntil(promise);
});

function calculateCacheStrategy(event) {
  const url = new URL(event.request.url);
  if (url.origin === location.origin) {
    for (const [regex, strategy] of CACHE_RULES) {
      if (regex.test(url.pathname)) return strategy;
    }
  }
  return STRATEGY_DEFAULT;
}

async function fetchAndCache(event, cache) {
  const response = await fetch(event.request);
  if (response.status === 200) {
    cache.put(event.request, response.clone());
  }
  return response;
}

function openCache() {
  return caches.open(CACHE_NAME);
}

function serviceWorkerInfo() {
  const info = { mode: APP_MODE, version: "{{.Version}}" };
  return new Response(new Blob([JSON.stringify(info)], { type: "application/json" }));
}
