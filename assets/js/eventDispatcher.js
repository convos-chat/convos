import {gotoUrl} from '../store/router';

function on(eventNames, cb) {
  eventNames.split('|').forEach(name => { on[name] = cb });
}

on('connection', ({params}, {user}) => {
  const conn = user.findDialog({connection_id: params.connection_id});
  conn.update({frozen: params.message || '', state: params.state});
});

on('frozen', (params, {user}) => {
  const conn = user.findDialog({connection_id: params.connection_id});
  const existing = user.findDialog(params);
  user.ensureDialog(params).participant(conn.nick, {me: true});
  if (!existing) gotoUrl(['', 'chat', params.connection_id, params.dialog_id].map(encodeURIComponent).join('/'));
});

on('join', (params, {user}) => {
  const dialog = user.findDialog(params);
  dialog.participant(params.nick, {});
  dialog.update({});
});

on('me', (params, {user}) => {
  const conn = user.ensureDialog({connection_id: params.connection_id});
  conn.update({nick: params.nick});
});

on('message', (params, {user}) => {
  const dialog = user.findDialog(params);
  if (dialog) return dialog.addMessage(params);

  const conn = user.ensureDialog({connection_id: params.connection_id});
  if (conn) return conn.addMessage(params);
});

on('mode', (params, {user}) => {
  const dialog = user.findDialog(params);
  dialog.participant(params.nick, {mode: params.mode});
  dialog.update({});
});

on('nick_change', (params, {user}) => {
  const dialog = user.findDialog(params);
  dialog.participant(params.new_nick, dialog.participants[params.old_nick] || {});
  delete dialog.participants[params.old_nick];
  dialog.update({});
});

on('part', (params, {user}) => {
  const dialog = user.findDialog(params);
  const participant = dialog.participants[params.nick] || {};

  if (participant.me) {
    user.removeDialog(params);

    // Change active conversation
    const conn = user.findDialog({connection_id: params.connection_id});
    const nextDialog = conn.dialogs().sort((a, b) => b.last_active.localeCompare(a.last_active))[0];
    const path = ['', 'chat', params.connection_id];
    if (nextDialog) path.push(nextDialog.dialog_id);
    gotoUrl(path.map(encodeURIComponent).join('/'));
  }
  else {
    delete dialog.participants[params.nick];
    dialog.update({});
  }
});

on('pong', (params, {user}) => {
  user.wsPongTimestamp = params.ts;
});

on('sent', (params, {user}) => {
  console.log('TODO: Handle sent event:', params);
});

on('quit', (params, {user}) => {
  console.log('TODO: Handle quit', params);
});

on('topic', (params, {user}) => {
  user.ensureDialog(params).update({topic: params.topic});
});

export default function eventDispatcher(params, {user}) {
  const method = on[params.event == 'state' ? params.type : params.event];
  if (method) return method(params, {user});
  console.log('TODO: Cannot dispatch event', params);
}