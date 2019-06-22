import {gotoUrl} from '../store/router';

function on(eventNames, cb) {
  eventNames.split('|').forEach(name => { on[name] = cb });
}

on('close|part', (params, {user}) => {
  user.removeDialog(params);

  const conn = user.findDialog({connection_id: params.connection_id});
  const dialog = conn.dialogs().sort((a, b) => b.last_active.localeCompare(a.last_active))[0];
  const path = ['', 'chat', params.connection_id];
  if (dialog) path.push(dialog.dialog_id);
  gotoUrl(path.map(encodeURIComponent).join('/'));
});

on('frozen', (params, {user}) => {
  const dialog = user.findDialog(params);
  if (dialog) return dialog.update(params);
  return console.log('TODO: Handle frozen if the dialog does not exist', params);
});

on('join', (params, {user}) => {
  user.ensureDialog(params);
  gotoUrl(['', 'chat', params.connection_id, params.dialog_id].map(encodeURIComponent).join('/'));
});

on('me', (params, {user}) => {
  console.log('TODO: Improve handling of "me" event.', params);
  const conn = user.ensureDialog({connection_id: params.connection_id});
  conn.update({nick: params.nick});
});

on('message', (params, {user}) => {
  const dialog = user.findDialog(params);
  if (dialog) return dialog.addMessage(params);

  const conn = user.ensureDialog({connection_id: params.connection_id});
  if (conn) return conn.addMessage(params);
});

on('nick_change', (params, {user}) => {
  console.log('TODO: Handle nick_change', params);
});

on('pong', (params, {user}) => {
  user.wsPongTimestamp = params.ts;
});

on('sent', (params, {user}) => {
  const message = (params.message || '').toLowerCase().match(/^\/(\S+)\s*(.*)/) || ['', ''];
  if (on[message[1]]) return on[message[1]](params, {user});
  return console.log('TODO: Handle sent event:', params);
});

on('quit', (params, {user}) => {
  console.log('TODO: Handle quit', params);
});

on('topic', (params, {user}) => {
  const dialog = user.findDialog(params);
  if (dialog) dialog.update({topic: params.topic});
});

export default function eventDispatcher(params, {user}) {
  const method = on[params.event == 'state' ? params.type : params.event];
  if (method) return method(params, {user});
  console.log('TODO: Cannot dispatch event', params);
}