import {derived, get, writable} from 'svelte/store';
import ConnURL from '../js/ConnURL';

const byName = (a, b) => a.name.localeCompare(b.name);

export function ensureConnection(conn) {
  conn.url = typeof conn.url == 'string' ? new ConnURL(conn.url) : conn.url;
  connections.set(get(connections).filter(c => c.connection_id != conn.connection_id).concat(conn));
}

export function ensureDialog(dialog) {
  dialogs.set(get(dialogs).filter(d => d.dialog_id != dialog.dialog_id).concat(dialog));
}

export async function getUser(api, params = {}) {
  const user = await api.execute('getUser', {
    connections: true,
    dialogs: true,
    notifications: false,
    ...params,
  });

  if (user.connections) user.connections.forEach(ensureConnection);
  if (user.dialogs) user.dialogs.forEach(ensureDialog);
  email.set(user.email);
  highlightKeywords.set(user.highlight_keywords.join(', '));
  unread.set(user.unread);

  return user;
}

export const connections = writable([]);
export const dialogs = writable([]);
export const email = writable('');
export const enableNotifications = writable(Notification.permission);
export const expandUrlToMedia = writable(false);
export const highlightKeywords = writable('');
export const unread = writable(0);

export const connectionsWithChannels = derived([connections, dialogs], ([$connections, $dialogs]) => {
  const map = {};
  $connections.forEach(conn => {
    conn.channels = [];
    conn.private = [];
    map[conn.connection_id] = conn;
  });

  $dialogs.forEach(dialog => {
    const conn = map[dialog.connection_id];
    dialog.path = encodeURIComponent(dialog.dialog_id);
    conn[dialog.is_private ? 'private' : 'channels'].push(dialog);
  });

  return Object.keys(map).sort().map(id => {
    map[id].channels.sort(byName);
    map[id].private.sort(byName);
    return map[id];
  });
});