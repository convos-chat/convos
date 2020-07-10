<script>
import Api from './js/Api';
import ConnectionSettings from './components/ConnectionSettings.svelte';
import DialogSettings from './components/DialogSettings.svelte';
import Fallback from './page/Fallback.svelte';
import Login from './page/Login.svelte';
import SidebarChat from './components/SidebarChat.svelte';
import User from './store/User';
import WebRTC from './store/WebRTC';
import {focusMainInputElements, loadScript, q, showEl, tagNameIs} from './js/util';
import {fade} from 'svelte/transition';
import {l} from './js/i18n';
import {onMount, setContext} from 'svelte';
import {replaceClassName} from './js/util';
import {route} from './store/Route';
import {setupRouting} from './routes';
import {viewport} from './store/Viewport';

const api = new Api(process.env.api_url, {debug: true});
const user = new User({api, isFirst: process.env.first_user, themes: process.env.themes});
const rtc = new WebRTC({embedMaker: user.embedMaker});

let [innerHeight, innerWidth] = [0, 0];

setContext('rtc', rtc);
setContext('user', user);

route.update({baseUrl: process.env.base_url});
user.on('update', (user, changed) => changed.hasOwnProperty('roles') && route.render());
user.on('update', (user, changed) => changed.hasOwnProperty('rtc') && rtc.update({peerConfig: user.rtc}));
user.omnibus.start({route, wsUrl: process.env.ws_url}); // Must be called after "baseUrl" is set

$: calculateTitle($route, $user);
$: settingsComponent = !$user.activeDialog.connection_id ? null : $user.activeDialog.dialog_id ? DialogSettings : ConnectionSettings;
$: viewport.update({height: innerHeight, width: innerWidth});
$: replaceBodyClassName($route, $user);

onMount(() => {
  const body = document.querySelector('body');
  loadScript(route.urlFor('/images/emojis.js'));
  q(document, '#hamburger_checkbox_toggle', el => { el.checked = false });
  if (user.showGrid) body.classList.add('with-grid');
  if (process.env.load_user) setupRouting(route, user);
  user.load(process.env.load_user);
});

function calculateTitle(route, user) {
  if (!document) return;
  const organizationName = process.env.organization_name;
  const title = user.unread ? '(' + user.unread + ') ' + route.title : route.title;

  document.title
    = organizationName == 'Convos' ? l('%1 - Convos', title) : l('%1 - Convos for %2', title, organizationName);
}

function replaceBodyClassName(route, user) {
  const appMode = route.component && route.requireLogin && user.is('authenticated') && !user.is('offline');
  replaceClassName('body', /(for-)(app|cms)/, appMode ? 'app' : 'cms');
}

function onGlobalKeydown(e) {
  // Esc
  if (e.keyCode == 27) {
    focusMainInputElements('chat_input');
    q(document, '.fullscreen-media-wrapper', el => el.click());
    return;
  }

  // Shift+Enter
  if (!(e.shiftKey && e.keyCode == 13)) return;
  e.preventDefault();
  focusMainInputElements();
}
</script>

<svelte:window
  on:focus="{() => user.email && user.omnibus.send('ping')}"
  on:keydown="{onGlobalKeydown}"
  bind:innerHeight="{innerHeight}"
  bind:innerWidth="{innerWidth}"/>

{#if $user.is('offline')}
  <Fallback/>
{:else if $route.component && $route.requireLogin && $user.is('authenticated')}
  <!--
    IMPORTANT! Looks like transition="..." inside <svelte:component/>,
    and a lot of $route updates prevents the <SidebarChat/> and/or
    $route.component from being destroyed.
    I (jhthorsen) really wanted to move the sidebars into the components,
    but it does not seem to be possible at this point.
    Not sure if this is a svelte issue or a problem with how Convos sue
    Reactive.js. Wild guess: A bad combination.
  -->

  {#if ($route.activeMenu == 'nav' || $viewport.isWide) && $route.activeMenu != 'default'}
    <SidebarChat transition="{{duration: $viewport.isWide ? 0 : 250, x: $viewport.width}}"/>
  {/if}

  {#if $route.activeMenu == 'settings'}
    <svelte:component this="{settingsComponent}" dialog="{$user.activeDialog}" transition="{{duration: 250, x: $viewport.isWide ? 0 : $viewport.width}}"/>
  {/if}

  <svelte:component this="{$route.component}"/>

  {#if $route.activeMenu && !$viewport.isWide}
    <div class="overlay" transition:fade="{{duration: 200}}" on:click="{() => $route.update({activeMenu: ''})}">&nbsp;</div>
  {/if}
{:else if $route.requireLogin}
  <Login/>
{:else}
  <svelte:component this="{$route.component || Fallback}"/>
{/if}
