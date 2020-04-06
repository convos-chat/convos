import page from 'page';
import qs from 'qs';
import {omnibus} from './store/Omnibus';
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

  render('/', route, RedirectToLast);
  render('/login', route, Login);
  render('/register', route, Login);
  page('/api/user/logout.html', refresh(route));

  render('/help', route, Help);
  render('/settings/account', route, SettingsAccount);
  render('/settings/connection', route, ConnectionAdd);
  render('/settings/conversation', route, DialogAdd);
  render('/settings', route, SettingsAdmin);
  render('/search', route, Search);

  render('/chat', route, Chat);
  render('/chat/:connection_id', route, Chat);
  render('/chat/:connection_id/:dialog_id', route, Chat);

  const noop = (ctx, next) => {};
  page('/docs/*', noop);
  page('/file/*', noop);
  page('/paste/*', noop);

  render('*', route, Fallback);

  listenToDialogEvents(route, user);
}

function beforeDispatch(route) {
  return (ctx, next) => {
    const removeEls = document.querySelectorAll('.js-remove');
    for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();
    route.update({ctx, query: qs.parse(ctx.querystring)});
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

function render(path, route, component) {
  page(path, (ctx, next) => {
    const requireLogin = [Fallback, Login, RedirectToLast].indexOf(component) == -1;
    const activeMenu = requireLogin ? '' : 'default';
    replaceClassName('body', /(is-logged-)\S+/, requireLogin ? 'in' : 'out');
    replaceClassName('body', /(page-)\S+/, route.pathParts[0].toLowerCase());
    route.update({activeMenu, component, requireLogin});
    if (omnibus.debug) console.log('[render:' + component.name + ']', path, JSON.stringify(route.pathParts));
    if (requireLogin) route.update({lastUrl: ctx.canonicalPath});
  });
}

function refresh(route) {
  return (ctx, next) => (location.href = route.baseUrl + ctx.path);
}
