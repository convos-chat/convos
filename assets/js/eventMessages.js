import {sortByName} from '../js/util';

const modes = {o: '@'};

function on(name, cb) {
  on[name] = cb;
}

on('connection', ({params}, {user}) => {
  const dialog = user.findDialog({connection_id: params.connection_id});
  dialog.addMessage(params.message
    ? {message: 'Connection state changed to %1: %2', vars: [params.state, params.message]}
    : {message: 'Connection state changed to %1.', vars: [params.state]}
  );
});

on('frozen', (params, {user}) => {
  if (params.frozen) user.findDialog(params).addMessage({message: params.frozen, vars: []});
});

on('join', (params, {user}) => {
  user.findDialog(params).addMessage({message: '%1 joined.', vars: [params.nick]});
});

on('message', (params, {user}) => {
  const dialog = user.ensureDialog(params);
  if (dialog) return dialog.addMessage(params);
});

on('mode', (params, {user}) => {
  user.findDialog(params).addMessage({message: '%1 got mode %2 from %3.', vars: [params.nick, params.mode, params.from]});
});

on('nick_change', (params, {user}) => {
  const conn = user.findDialog({connection_id: params.connection_id});
  conn.dialogs().forEach(dialog => {
    const existing = dialog.participants[params.new_nick];
    if (!existing) return;
    if (existing.me) return dialog.addMessage({message: 'You changed nick to %1.', vars: [params.new_nick]});
    return dialog.addMessage({message: '%1 changed nick to %2.', vars: [params.old_nick, params.new_nick]});
  });
});

on('part', (params, {user}) => {
  const dialog = user.findDialog(params);
  if (!dialog) return; // You parted

  const msg = {message: '%1 parted.', vars: [params.nick]};
  if (params.kicker) {
    msg.message = '%1 was kicked by %2' + (params.message ? ': %3' : '');
    msg.vars.push(params.kicked);
    msg.vars.push(params.message);
  }
  else if (params.message) {
    msg.message += ' Reason: %2';
    msg.vars.push(params.message);
  }

  dialog.addMessage(msg);
});

on('participants', (params, {user}) => {
  const dialog = user.findDialog(params);
  const msg = {message: 'Participants: %1', vars: []};

  const participants = params.participants.sort(sortByName).map(p => {
    return (modes[p.mode] || '') + p.name;
  });

  if (participants.length > 1) {
    msg.message += ' and %2.';
    msg.vars[1] = participants.pop();
  }

  msg.vars[0] = participants.join(', ');
  dialog.addMessage(msg);
});

on('quit', (params, {user}) => {
  on.part(params, {user});
});

on('topic', (params, {user}) => {
  user.ensureDialog(params).addMessage(params.topic
    ? {message: 'Topic is: %1', vars: [params.topic]}
    : {message: 'No topic is set.', vars: []}
  );
});

export default function eventMessages(params, {user}) {
  const method = on[params.event == 'state' ? params.type : params.event];
  if (method) return method(params, {user});
  if (params.participants) on.participants(params, {user});
}