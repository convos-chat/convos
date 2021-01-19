<script>
import ThemeManager from './store/ThemeManager';
import User from './store/User';
import {api} from './js/Api';
import {fade} from 'svelte/transition';
import {i18n} from './store/I18N';
import {loadScript, q, settings} from './js/util';
import {notify} from './js/Notify';
import {route} from './store/Route';
import {getSocket} from './js/Socket';
import {setContext} from 'svelte';
import {setupRouting} from './routes';

// Page components
import ConnectionSettings from './components/ConnectionSettings.svelte';
import ConversationSettings from './components/ConversationSettings.svelte';
import Fallback from './page/Fallback.svelte';
import Login from './page/Login.svelte';
import ChatSidebar from './components/ChatSidebar.svelte';

const socket = getSocket('/events');
const user = new User({});

let [innerHeight, innerWidth] = [0, 0];
let readyStateNotification = {closed: true};

// This section is to help debugging the WebSocket issue in production
socket.update({debug: 'WebSocket'});
window.convosWebSockeet = socket;

route.update({baseUrl: settings('base_url')});
socket.update({url: route.wsUrlFor('/events')});
registerServiceWorker().catch(err => console.error('[serviceWorker]', err));
setupRouting(route, user);
loadScript(route.urlFor('/images/emojis.js'));

setContext('api', api('/api').update({url: route.urlFor('/api')}).toFunction());
setContext('socket', socket);
setContext('themeManager', new ThemeManager().start());
setContext('user', user);

notify.on('click', (params) => (params.path && route.go(params.path)));
socket.on('update', socketChanged);
user.on('update', (user, changed) => changed.hasOwnProperty('roles') && route.render());
i18n.load().then(() => user.load());

$: isWide = innerWidth > 800;
$: loggedInRoute = $route.component && $route.requireLogin && user.is('authenticated') ? true : false;
$: settingsComponent = !$user.activeConversation.connection_id ? null : $user.activeConversation.conversation_id ? ConversationSettings : ConnectionSettings;
$: settings('app_mode', loggedInRoute);
$: settings('notify_enabled', loggedInRoute);
$: calculateTitle($route, $user);

function calculateTitle(route, user) {
  if (!document) return;
  const organizationName = settings('organization_name');
  const title = user.unread ? '(' + user.unread + ') ' + route.title : route.title;

  document.title
    = organizationName == 'Convos' ? i18n.l('%1 - Convos', title) : i18n.l('%1 - Convos for %2', title, organizationName);
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

<svelte:window on:focus="{() => user.email && socket.open()}" bind:innerHeight="{innerHeight}" bind:innerWidth="{innerWidth}"/>

{#if loggedInRoute}
  <!--
    IMPORTANT! Looks like transition="..." inside <svelte:component/>,
    and a lot of $route updates prevents the <ChatSidebar/> and/or
    $route.component from being destroyed.
    I (jhthorsen) really wanted to move the sidebars into the components,
    but it does not seem to be possible at this point.
    Not sure if this is a svelte issue or a problem with how Convos sue
    Reactive.js. Wild guess: A bad combination.
  -->

  {#if ($route.activeMenu == 'nav' || isWide) && $route.activeMenu != 'default'}
    <ChatSidebar transition="{{duration: isWide ? 0 : 250, x: innerWidth}}"/>
  {/if}

  {#if $route.activeMenu == 'settings'}
    <svelte:component this="{settingsComponent}" conversation="{$user.activeConversation}" transition="{{duration: 250, x: isWide ? 0 : innerWidth}}"/>
  {/if}

  <svelte:component this="{$route.component}"/>

  {#if $route.activeMenu && !isWide}
    <div class="overlay" transition:fade="{{duration: 200}}" on:click="{() => $route.update({activeMenu: ''})}">&nbsp;</div>
  {/if}
{:else if $route.requireLogin}
  <Login/>
{:else}
  <svelte:component this="{$route.component || Fallback}"/>
{/if}
