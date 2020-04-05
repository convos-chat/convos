import page from 'page';
import qs from 'qs';
import {replaceClassName} from './js/util';

import Chat from './page/Chat.svelte';
import ConnectionAdd from './page/ConnectionAdd.svelte';
import DialogAdd from './page/DialogAdd.svelte';
import Fallback from './page/Fallback.svelte';
import Help from './page/Help.svelte';
import Login from './page/Login.svelte';
import RedirectToLast from './page/RedirectToLast.svelte';
import Search from './page/Search.svelte';
import SettingsAccount from './page/SettingsAccount.svelte';
import SettingsAdmin from './page/SettingsAdmin.svelte';

export function setupRouting(route, user) {
  page('*', beforeDispatch(route));

  page('/', render(route, RedirectToLast));
  page('/login', render(route, Login));
  page('/register', render(route, Login));
  page('/api/user/logout.html', refresh(route));

  page('/help', render(route, Help));
  page('/settings/account', render(route, SettingsAccount));
  page('/settings/connection', render(route, ConnectionAdd));
  page('/settings/conversation', render(route, DialogAdd));
  page('/settings', render(route, SettingsAdmin));
  page('/search', render(route, Search));

  page('/chat', render(route, Chat));
  page('/chat/:connection_id', render(route, Chat));
  page('/chat/:connection_id/:dialog_id', render(route, Chat));

  const noop = (ctx, next) => {};
  page('/docs/*', noop);
  page('/file/*', noop);
  page('/paste/*', noop);

  page('*', render(route, Fallback));

  listenToDialogEvents(route, user);
}

function beforeDispatch(route) {
  return (ctx, next) => {
    const removeEls = document.querySelectorAll('.js-remove');
    for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();
    route.update({ctx, query: qs.parse(location.search.slice(1))});
    next();
  };
}

function listenToDialogEvents(route, user) {
  user.omnibus.on('wsEventSentJoin', e => {
    route.go(route.dialogPath(e));
  });

  user.omnibus.on('wsEventSentPart', e => {
    const conn = user.findDialog({connection_id: e.connection_id});
    if (!conn) return route.go('/settings/connection');
    const dialog = conn.dialogs.toArray()[0];
    route.go(dialog ? dialog.path : '/settings/conversation');
  });
}

function render(route, component) {
  return (ctx, next) => {
    const requireLogin = [Fallback, Login, RedirectToLast].indexOf(component) == -1;
    const activeMenu = requireLogin ? 'nav' : 'default';
    replaceClassName('body', /(is-logged-)\S+/, requireLogin ? 'in' : 'out');
    replaceClassName('body', /(page-)\S+/, (component.name || route.pathParts[0]).toLowerCase());
    route.update({activeMenu, component, requireLogin});
    if (requireLogin) route.update({lastUrl: ctx.canonicalPath});
  };
}

function refresh(route) {
  return (ctx, next) => (location.href = route.baseUrl + ctx.path);
}
