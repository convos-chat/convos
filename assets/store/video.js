import {route} from '../store/Route';
import {writable} from '../js/storeGenerator';

function conversationName(conversation) {
  const name = conversation.is('private')
    ? conversation.participants.nicks().sort().join('-and-')
    : conversation.title;
  return encodeURIComponent(name).toLowerCase();
}

export const videoService = writable(null, {
  conversationToInternalUrl(conversation) {
    const baseUrl = this.get();
    if (!baseUrl) return null;
    const rel = route.urlFor('/video/' + baseUrl.hostname + '/' + conversationName(conversation));
    return new URL(rel, location.href).href;
  },
  conversationToExternalUrl(conversation) {
    const baseUrl = this.get();
    return baseUrl ? new URL('/' + conversationName(conversation), baseUrl).href : null;
  },
  fromString(str) {
    this.set(str ? new URL(str) : null);
  },
});

export const videoWindow = writable(null, {
  close() {
    const w = this.get();
    return w ? [true, w.close(), this.set(null)][0] : false;
  },
  open(url, q = {}) {
    if (!this.window) this.window = window;
    url = url.toString();
    if (q.nick) url += '?nick=' + encodeURIComponent(q.nick);
    const w = this.window.open(url, 'convos_video');
    ['beforeunload', 'close'].forEach(name => w.addEventListener(name, () => this.set(null)));
    this.set(w);
  },
});
