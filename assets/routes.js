import Chat from './page/Chat.svelte';
import Connections from './page/Connections.svelte';
import ConversationAdd from './page/ConversationAdd.svelte';
import Fallback from './page/Fallback.svelte';
import Help from './page/Help.svelte';
import Login from './page/Login.svelte';
import Notifications from './page/Notifications.svelte';
import Search from './page/Search.svelte';
import SettingsAccount from './page/SettingsAccount.svelte';
import SettingsAdmin from './page/SettingsAdmin.svelte';
import SettingsAdminUsers from './page/SettingsAdminUsers.svelte';

export function setupRouting(route, user) {
  route.to('/login', render(Login));
  route.to('/register', render(Login));

  route.to('/help', render(Help));
  route.to('/settings/account', render(SettingsAccount));
  route.to('/settings/connections', render(Connections));
  route.to('/settings/conversation', render(ConversationAdd));
  route.to('/settings/users', render(SettingsAdminUsers));
  route.to('/settings', render(SettingsAdmin));
  route.to('/search', render(Search));

  route.to('/chat', render(Notifications));
  route.to('/chat/:connection_id', render(Chat));
  route.to('/chat/:connection_id/:conversation_id', render(Chat));

  const noop = () => {};
  route.to('/doc/*', noop);
  route.to('/file/*', noop);
  route.to('/paste/*', noop);

  route.to('/', render(Login));
  route.to('*', render(Fallback));

  user.on('wsEventSentJoin', e => {
    route.go(route.conversationPath(e));
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
