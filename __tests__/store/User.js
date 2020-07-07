import User from '../../assets/store/User';

test('ensureDialog connection', () => {
  const user = new User({});

  const conn = user.ensureDialog({connection_id: 'irc-foo'});
  expect(conn.connection_id).toBe('irc-foo');
  expect(user.activeDialog.connection_id).toBe('');

  // Upgrade activeDialog
  user.setActiveDialog({connection_id: 'irc-bar'});
  user.ensureDialog({connection_id: 'irc-bar'});
  expect(user.activeDialog.connection_id).toBe('irc-bar');
  expect(user.activeDialog.dialog_id).toBe(undefined);

  // Upgrade activeDialog from connection
  user.setActiveDialog({connection_id: 'irc-foo', dialog_id: '#cf'});
  expect(user.activeDialog.frozen).toBe('Not found.');
  conn.ensureDialog({dialog_id: '#cf'});
  expect(user.activeDialog.dialog_id).toBe('#cf');
  expect(user.activeDialog.frozen).toBe('');
});

test('ensureDialog dialog', () => {
  const user = new User({});

  const dialog = user.ensureDialog({connection_id: 'irc-foo', dialog_id: '#cf'});
  expect(dialog.connection_id).toBe('irc-foo');
  expect(user.activeDialog.connection_id).toBe('');
  expect(user.activeDialog.dialog_id).toBe('notifications');

  // Upgrade activeDialog
  user.setActiveDialog({connection_id: 'irc-bar', dialog_id: '#cr'});
  expect(user.findDialog({connection_id: 'irc-bar', dialog_id: '#cr'})).toBe(null);
  user.ensureDialog({connection_id: 'irc-bar', dialog_id: '#cr'});
  expect(user.activeDialog.connection_id).toBe('irc-bar');
  expect(user.activeDialog.dialog_id).toBe('#cr');
});

test('removeDialog connection', () => {
  const user = new User({});

  const conn = user.ensureDialog({connection_id: 'irc-baz'});
  user.update({activeDialog: conn});
  expect(user.activeDialog == conn).toBe(true);

  user.removeDialog(conn);
  expect(user.activeDialog != conn).toBe(true);
  expect(user.activeDialog.connection_id).toBe('irc-baz');
  expect(user.connections.size).toBe(0);
});

test('removeDialog dialog', () => {
  const user = new User({});

  const conn = user.ensureDialog({connection_id: 'irc-bax'});
  const dialog = user.ensureDialog({connection_id: 'irc-bax', dialog_id: '#cx'});

  user.update({activeDialog: dialog});
  expect(user.activeDialog == dialog).toBe(true);

  user.removeDialog(dialog);
  expect(user.activeDialog != dialog).toBe(true);
  expect(user.activeDialog.connection_id).toBe('irc-bax');
  expect(user.activeDialog.dialog_id).toBe('#cx');
  expect(user.connections.size).toBe(1);
  expect(user.dialogs().length).toBe(0);
});
