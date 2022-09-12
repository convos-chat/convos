<script>
// Pages
import Chat from './page/Chat.svelte';
import Connections from './page/Connections.svelte';
import ConnectionProfileSettings from './page/ConnectionProfileSettings.svelte';
import ConnectionSettings from './page/ConnectionSettings.svelte';
import ConversationAdd from './page/ConversationAdd.svelte';
import Fallback from './page/Fallback.svelte';
import Help from './page/Help.svelte';
import Login from './page/Login.svelte';
import Notifications from './page/Notifications.svelte';
import Search from './page/Search.svelte';
import SettingsAccount from './page/SettingsAccount.svelte';
import SettingsAdmin from './page/SettingsAdmin.svelte';
import SettingsAdminUsers from './page/SettingsAdminUsers.svelte';
import SettingsFiles from './page/SettingsFiles.svelte';

// Other components and utilties
import features from './js/features';
import ChatSidebar from './components/ChatSidebar.svelte';
import ThemeManager from './store/ThemeManager';
import User from './store/User';
import {activeMenu, viewport} from './store/viewport';
import {convosApi} from './js/Api';
import {fade} from 'svelte/transition';
import {getSocket} from './js/Socket';
import {i18n} from './store/I18N';
import {notify} from './js/Notify';
import {settings} from './js/util';
import {route} from './store/Route';
import {setContext, tick} from 'svelte';

const socket = getSocket('/events');
const themeManager = new ThemeManager().start();
const user = new User({});

let prevPath = route.path;
let width = 0;
let readyStateNotification = {closed: true};
let title = i18n.l('Chat');

// This section is to help debugging the WebSocket issue in production
socket.update({debug: 'WebSocket'});
window.convosWebSockeet = socket;

convosApi.url(route.urlFor('/api'));
route.update({baseUrl: settings('base_url'), enabled: true});
socket.update({url: route.wsUrlFor('/events')});
user.on('wsEventSentJoin', e => route.go(route.conversationPath(e)));
registerServiceWorker().catch(err => console.error('[serviceWorker]', err));

setContext('socket', socket);
setContext('themeManager', themeManager);
setContext('user', user);

notify.on('click', (params) => (params.path && route.go(params.path)));
socket.on('update', socketChanged);
i18n.load().then(() => user.load());

$: features[$themeManager.compactDisplay ? 'add' : 'remove']('compact-display');
$: routeOrUserChanged($route, $user);
$: setTitle(title, $user);
$: viewport.setWidth(width);
$: user.update({unreadIncludePrivateMessages: $viewport.isSingleColumn});

function setTitle(title, $user) {
  if (!document) return;
  const organizationName = settings('organization_name');
  const unread = $user.notifications.notifications ? '(' + $user.notifications.notifications + ') ' : '';

  document.title = organizationName == 'Convos'
    ? i18n.l('%1 - Convos', unread + i18n.l(title))
    : i18n.l('%1 - Convos for %2', unread + i18n.l(title), organizationName);
}

async function registerServiceWorker() {
  if (!navigator.serviceWorker) return {};
  const reg = await navigator.serviceWorker.register(route.urlFor('/sw.js'));
  const res = await fetch(route.urlFor('/sw/info'));
  const info = res.status == 200 && await res.json() || {mode: '', version: '0.00'};
  if (info.version == settings('version')) return {};
  console.info('[serviceWorker.update]', settings('version'), info);
  reg.update();
}

async function routeOrUserChanged(route, user) {
  if (user.email) i18n.emojis.load();
  features[user.email ? 'add' : 'remove']('notify');
  await tick();
  const appOrCms = user.is(['loading', 'pending']) || document.querySelector('.cms-main') ? 'cms' : 'app';
  document.body.className = document.body.className.replace(/for-\w+/, 'for-' + appOrCms);

  if (prevPath != route.path) {
    prevPath = route.path;
    $activeMenu = '';
  }

  if (route.pathParts.length == 0) { // path = "/" or path = ""
    const url = !user.email ? '/login' : user.lastUrl || '/chat';
    route.go(url, {replace: true});
  }
  else if (user.email) {
    user.update({lastUrl: location.href});
  }
}

function socketChanged(socket) {
  if (socket.is('open')) {
    return readyStateNotification.close && readyStateNotification.close();
  }

  const message
    = navigator.onLine === false ? i18n.l('You seem to be offline.')
    : socket.error               ? i18n.l(socket.error)
    : socket.is('connecting')    ? i18n.l('Connecting to Convos...')
    :                              i18n.l('Connection to Convos is %1.', i18n.l(socket.readyStateHuman));

  if (readyStateNotification.body == message) return;
  if (readyStateNotification.close) readyStateNotification.close();
  readyStateNotification = notify.showInApp(message, {closeAfter: -1, title: i18n.l('Status')});
}
</script>

<svelte:window on:focus="{() => user.email && socket.open()}" bind:innerWidth="{width}"/>

{#if $user.is(['loading', 'pending'])}
  <Fallback/>
{:else if $user.email}
  {#if $activeMenu == 'nav' || !$viewport.isSingleColumn}
    <ChatSidebar transition="{{duration: $viewport.isSingleColumn ? 250 : 0, x: width}}"/>
  {/if}

  {#if $route.path.match(/\/chat\/./)}
    <Chat connection_id={$route.pathParts[1]} conversation_id={$route.pathParts[2]} bind:title/>
  {:else if $route.path.indexOf('/chat') == 0}
    <Notifications bind:title/>
  {:else if $route.path == '/help'}
    <Help bind:title/>
  {:else if $route.path == '/search'}
    <Search bind:title/>
  {:else if $route.path == '/settings'}
    <SettingsAdmin bind:title/>
  {:else if $route.path == '/settings/account'}
    <SettingsAccount bind:title/>
  {:else if $route.path == '/settings/connections'}
    <Connections bind:title/>
  {:else if $route.path == '/settings/files'}
    <SettingsFiles bind:title/>
  {:else if $route.path.indexOf('/settings/connection/') == 0}
    <ConnectionSettings connection_id="{$route.pathParts[2]}" bind:title/>
  {:else if $route.path.indexOf('/settings/connection-profile/') == 0}
    <ConnectionProfileSettings profile_id="{$route.pathParts[2]}" bind:title/>
  {:else if $route.path == '/settings/conversation'}
    <ConversationAdd bind:title/>
  {:else if $route.path == '/settings/users'}
    <SettingsAdminUsers bind:title/>
  {:else if $route.path == '/login' || $route.path == '/register'}
    <Login bind:title/>
  {:else}
    <Fallback bind:title/>
  {/if}

  {#if $activeMenu && $viewport.haSingleColumn}
    <div class="overlay" transition:fade="{{duration: 200}}" on:click="{() => { $activeMenu = '' }}">&nbsp;</div>
  {/if}
{:else}
  <Login bind:title/>
{/if}
