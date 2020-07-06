
import Chat from './page/Chat.svelte';
import ConnectionAdd from './page/ConnectionAdd.svelte';
import DialogAdd from './page/DialogAdd.svelte';
import Fallback from './page/Fallback.svelte';
import Help from './page/Help.svelte';
import Login from './page/Login.svelte';
import Search from './page/Search.svelte';
import SettingsAccount from './page/SettingsAccount.svelte';
import SettingsAdmin from './page/SettingsAdmin.svelte';

export function setupRouting(route, user) {
  route.to('/login', render(Login));
  route.to('/register', render(Login));

  route.to('/help', render(Help));
  route.to('/settings/account', render(SettingsAccount));
  route.to('/settings/connection', render(ConnectionAdd));
  route.to('/settings/conversation', render(DialogAdd));
  route.to('/settings', render(SettingsAdmin));
  route.to('/search', render(Search));

  route.to('/chat', render(Search));
  route.to('/chat/:connection_id', render(Chat));
  route.to('/chat/:connection_id/:dialog_id', render(Chat));

  const noop = () => {};
  route.to('/doc/*', noop);
  route.to('/file/*', noop);
  route.to('/paste/*', noop);

  route.to('/', render(Login));
  route.to('*', render(Fallback));

  listenToDialogEvents(route, user);
}

function listenToDialogEvents(route, user) {
  user.on('wsEventSentJoin', e => {
    route.go(route.dialogPath(e));
  });

  user.on('wsEventSentPart', e => {
    const conn = user.findDialog({connection_id: e.connection_id});
    if (!conn) return route.go('/settings/connection');
    const dialog = conn.dialogs.toArray()[0];
    route.go(dialog ? dialog.path : '/settings/conversation');
  });
}

function render(component) {
  return (route) => {
    const removeEls = document.querySelectorAll('.js-remove');
    for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();
    const requireLogin = [Fallback, Login].indexOf(component) == -1;
    route.update({component, requireLogin});
    if (requireLogin) route.update({lastUrl: location.href});
  };
}
