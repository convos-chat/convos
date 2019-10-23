<script>
import Api from './js/Api';
import hljs from './js/hljs';
import User from './store/User';
import {activeMenu, container, currentUrl, docTitle, gotoUrl, historyListener} from './store/router';
import {closestEl, loadScript, tagNameIs} from './js/util';
import {fade} from 'svelte/transition';
import {onMount, setContext} from 'svelte';

// Pages
import Chat from './page/Chat.svelte';
import ConnectionAdd from './page/ConnectionAdd.svelte';
import DialogAdd from './page/DialogAdd.svelte';
import Help from './page/Help.svelte';
import Login from './page/Login.svelte';
import Register from './page/Register.svelte';
import Settings from './page/Settings.svelte';

window.hljs = hljs; // Required by paste plugin

// Routing
const loggedInPages = {
  'add/connection': ConnectionAdd,
  'add/conversation': DialogAdd,
  'chat': Chat,
  'help': Help,
  'settings': Settings,
};

const loggedOutPages = {
  'login': Login,
  'register': Register,
};

const settings = [window.__convos, delete window.__convos][0];
const api = new Api(settings.apiUrl, {debug: true});
const user = new User({api, wsUrl: settings.wsUrl});
const getUserOp = user.getUserOp;
const notifications = user.notifications;

let containerWidth = 0;
let pageComponent = null;

$: container.set({small: containerWidth < 800, width: containerWidth});
$: calculatePage($currentUrl, $getUserOp);
$: if (document) document.title = $notifications.unread ? '(' + $notifications.unread + ') ' + $docTitle : $docTitle;

currentUrl.base = settings.baseUrl;

setContext('settings', settings);
setContext('user', user);

onMount(async () => {
  if (!settings.chatMode) return;

  const dialogEventUnlistener = user.on('dialogEvent', calculateNewPath);
  const historyUnlistener = historyListener();
  user.load();
  document.addEventListener('click', toggleMenu);
  if (user.showGrid) document.querySelector('body').classList.add('with-grid');

  return () => {
    document.removeEventListener('click', toggleMenu);
    dialogEventUnlistener();
    historyUnlistener();
  };
});

function calculateNewPath(params) {
  let path = ['', 'chat'];
  if (params.connection_id) path.push(params.connection_id);

  // Do not want to show settings for the new dialog
  $activeMenu = '';

  if (params.type == 'part') {
    const el = document.querySelector('.sidebar-left [href$="' + path.map(encodeURIComponent).join('/') + '"]');
    gotoUrl(el ? el.href : '/chat');
  }
  else {
    if (params.dialog_id) path.push(params.dialog_id);
    gotoUrl(path.map(encodeURIComponent).join('/'));
  }
}

function calculatePage($url, getUserOp) {
  // Remember last chat
  if ($url.pathParts[0] == 'chat') user.update({lastUrl: $url.toString()});

  // Figure out current page
  const pages = getUserOp.is('success') ? loggedInPages : loggedOutPages;
  const pageName = pages[$url.path] ? $url.path : $url.pathParts[0] || '';
  const nextPageComponent = pages[pageName];

  // Goto a valid page
  if (nextPageComponent) {
    if (nextPageComponent != pageComponent) pageComponent = nextPageComponent;

    // Enable complex styling
    replaceBodyClassName(/(is-logged-)\S+/, getUserOp.is('success') ? 'in' : 'out');
    replaceBodyClassName(/(page-)\S+/, pageName.replace(/\W+/g, '_') || 'loading');
  }
  else if (getUserOp.is('success')) {
    const lastUrl = user.lastUrl;
    loadScript('/images/emojis.js');
    gotoUrl(lastUrl || (user.connections.size ? '/chat' : '/add/connection'), {replace: true});
  }
  else if (getUserOp.is('error')) {
    gotoUrl('/login', {replace: true});
  }

  // Remove original components
  const removeEls = document.querySelectorAll('.js-remove');
  for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();
}

function debugClick(e) {
  // This is useful if you want to see on server side what is being clicked on
  // user.events.send({method: 'debug', type: e.type, target: e.target.tagName, className: e.target.className});
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

function replaceBodyClassName(re, replacement) {
  const body = document.querySelector('body');
  body.className = body.className.replace(re, (all, prefix) => prefix + replacement);
}

function toggleMenu(e) {
  const linkEl = closestEl(e.target, 'a');
  if (closestEl(e.target, '.sidebar-left') && !linkEl) return;

  const toggle = linkEl && linkEl.href.match(/#(activeMenu):(\w*)/) || ['', '', ''];
  if (toggle[1] || $activeMenu) e.preventDefault();
  $activeMenu = toggle[2] == $activeMenu ? '' : toggle[2];
}
</script>

<svelte:window
  on:click="{debugClick}"
  on:focus="{() => user.events.ensureConnected()}"
  on:keydown="{onGlobalKeydown}"
  bind:innerWidth="{containerWidth}"/>

<svelte:component this="{pageComponent}"/>

{#if $activeMenu && $container.small}
  <div class="overlay" transition:fade="{{duration: 200}}">&nbsp;</div>
{/if}
