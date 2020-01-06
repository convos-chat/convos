<script>
import Api from './js/Api';
import hljs from './js/hljs';
import SidebarChat from './components/SidebarChat.svelte';
import User from './store/User';
import {activeMenu, calculateCurrentPageComponent, container, currentUrl, docTitle, gotoUrl, historyListener, pageComponent} from './store/router';
import {closestEl, loadScript, tagNameIs} from './js/util';
import {fade} from 'svelte/transition';
import {onMount, setContext} from 'svelte';
import {setTheme} from './store/themes';
import {urlFor} from './store/router';

// Routing
import Chat from './page/Chat.svelte';
import ConnectionAdd from './page/ConnectionAdd.svelte';
import DialogAdd from './page/DialogAdd.svelte';
import Fallback from './page/Fallback.svelte';
import Help from './page/Help.svelte';
import Login from './page/Login.svelte';
import Settings from './page/Settings.svelte';
import SettingsAccount from './page/SettingsAccount.svelte';

export const routingRules = [
  [new RegExp('^/(file|paste)'), null, {}],
  [new RegExp('^/docs'), null, {}],
  [new RegExp('^/$'), Login, {user: 'pending'}],
  [new RegExp('.*'), Fallback, {user: 'offline'}],
  [new RegExp('^/(login|register)'), Login, {}],
  [new RegExp('^/settings/connection'), ConnectionAdd, {user: 'loggedIn'}],
  [new RegExp('^/settings/conversation'), DialogAdd, {user: 'loggedIn'}],
  [new RegExp('^/settings/account'), SettingsAccount, {user: 'loggedIn'}],
  [new RegExp('^/settings'), Settings, {user: 'loggedIn'}],
  [new RegExp('^/chat'), Chat, {user: 'loggedIn'}],
  [new RegExp('^/help'), Help, {user: 'loggedIn'}],
  [new RegExp('^/$'), null, {user: ['error', 'success'], gotoLast: true}],
  [new RegExp('.*'), Fallback, {}],
];

const settings = [window.__convos, delete window.__convos][0];
const api = new Api(settings.api_url, {debug: true});
const user = new User({api, wsUrl: settings.ws_url});
const notifications = user.notifications;

let containerWidth = 0;

window.hljs = hljs; // Required by paste plugin
currentUrl.base = settings.base_url;
user.events.listenToGlobalEvents();
setContext('settings', settings);
setContext('user', user);

$: container.set({wideScreen: containerWidth > 800, width: containerWidth});
$: calculateCurrentPageComponent($currentUrl, $user, routingRules);
$: setTheme($user.theme);
$: if (document) document.title = $user.unread ? '(' + $user.unread + ') ' + $docTitle : $docTitle;
$: showSidebarChat = $pageComponent.routerOptions.user == 'loggedIn';

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js').then(reg => {
    user.update({latestVersion: settings.asset_version});
    reg.update();
  }).catch(err => {
    console.log('[Convos] ServiceWorker registration failed:', err);
  });
}

onMount(() => {
  loadScript(currentUrl.base + '/images/emojis.js');
  if (settings.load_user) user.load();
  if (user.showGrid) document.querySelector('body').classList.add('with-grid');

  const unsubscribe = [];
  unsubscribe.push(historyListener());
  unsubscribe.push(user.on('wsEventSentJoin', onChannelListChange));
  unsubscribe.push(user.on('wsEventSentPart', onChannelListChange));

  return () => unsubscribe.forEach(cb => cb());
});

function onChannelListChange(params) {
  let path = ['', 'chat', params.connection_id];

  // Do not want to show settings for the new dialog
  $activeMenu = '';

  if (params.command[0] == 'part') {
    const el = document.querySelector('.sidebar-left [href$="' + path.map(encodeURIComponent).join('/') + '"]');
    gotoUrl(el ? el.href : '/chat');
  }
  else {
    if (params.dialog_id) path.push(params.dialog_id);
    gotoUrl(path.map(encodeURIComponent).join('/'));
  }
}

function onGlobalKeydown(e) {
  if (!(e.shiftKey && e.keyCode == 13)) return; // Shift+Enter
  e.preventDefault();

  const searchInput = document.getElementById('sidebar_left_search_input');
  const targetEl = document.activeElement;
  if (targetEl != searchInput && !tagNameIs(targetEl, 'body')) return searchInput.focus();

  const selectors = ['#chat_input_textarea', '.main input[type="text"]', '.main a', '#sidebar_left_search_input'];
  for (let i = 0; i < selectors.length; i++) {
    const el = document.querySelector(selectors[i]);
    if (el) return el.focus();
  }
}

function onWindowClick(e) {
  // This is useful if you want to see on server side what is being clicked on
  // user.send({method: 'debug', type: e.type, target: e.target.tagName, className: e.target.className});

  // Call methods on user, such as user.ensureConnected() with href="#call:user:ensureConnected"
  const linkEl = closestEl(e.target, 'a');
  const action = linkEl && linkEl.href.match(/#call:(\w+):(\w+)/) || ['', '', ''];
  if (action[2]) {
    e.preventDefault();
    switch(action[1]) {
      case 'events': return user.events[action[2]]();
      case 'user': return user[action[2]]();
    }
  }

  // Internal link
  if (linkEl && linkEl.target == '_self') {
    e.preventDefault();
    gotoUrl(linkEl.href);
    return;
  }

  // Toggle activeMenu with href="#activeMenu:nav", where "nav" can be "", "nav" or "settings"
  const toggle = linkEl && linkEl.href.match(/(.*)#(activeMenu):(\w*)/) || ['', '', '', ''];
  if (toggle[1].indexOf('http') == 0 && $currentUrl.toString() != toggle[1]) gotoUrl(toggle[1]);
  if (closestEl(e.target, '.sidebar-left') && !linkEl) return;
  if (closestEl(e.target, '.main') && !toggle[3]) return;
  if (toggle[2] || $activeMenu) e.preventDefault();
  $activeMenu = toggle[3] == $activeMenu ? '' : toggle[3];
}

function onWindowFocus() {
  user.ensureConnected();
}
</script>

<svelte:window
  on:click="{onWindowClick}"
  on:focus="{onWindowFocus}"
  on:keydown="{onGlobalKeydown}"
  bind:innerWidth="{containerWidth}"/>

{#if $pageComponent}
  {#if showSidebarChat && ($activeMenu == 'nav' || $container.wideScreen)}
    <SidebarChat transition="{{duration: $container.wideScreen ? 0 : 250, x: $container.width}}"/>
  {/if}

  <svelte:component this="{$pageComponent}"/>

  {#if $activeMenu && !$container.wideScreen}
    <div class="overlay" transition:fade="{{duration: 200}}">&nbsp;</div>
  {/if}
{/if}
