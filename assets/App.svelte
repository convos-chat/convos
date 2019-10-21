<script>
import Api from './js/Api';
import hljs from './js/hljs';
import User from './store/User';
import {activeMenu, baseUrl, container, docTitle, gotoUrl, historyListener, pathname, pathParts} from './store/router';
import {closestEl, loadScript} from './js/util';
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
const notifications = user.notifications;

let containerWidth = 0;
let pageComponent = null;

$: container.set({small: containerWidth < 800, width: containerWidth});
$: if (document) document.title = $notifications.unread ? '(' + $notifications.unread + ') ' + $docTitle : $docTitle;
$: calculatePage($pathParts, $user);

setContext('settings', settings);
setContext('user', user);

baseUrl.set(settings.baseUrl);

onMount(async () => {
  if (!settings.chatMode) return;

  const dialogEventUnlistener = user.on('dialogEvent', calculateNewPath);
  const historyUnlistener = historyListener();
  user.load();
  document.addEventListener('click', hideMenu);

  return () => {
    document.removeEventListener('click', hideMenu);
    dialogEventUnlistener();
    historyUnlistener();
  };
});

function calculateNewPath(params) {
  let path = ['', 'chat'];
  if (params.connection_id) path.push(params.connection_id);

  if (params.type == 'part') {
    const el = document.querySelector('.sidebar-wrapper [href$="' + path.map(encodeURIComponent).join('/') + '"]');
    gotoUrl(el ? el.href : '/chat');
  }
  else {
    if (params.dialog_id) path.push(params.dialog_id);
    gotoUrl(path.map(encodeURIComponent).join('/'));
  }
}

function calculatePage(pathParts, user) {

  // Remember last chat
  if (pathParts.indexOf('chat') != -1) user.update({lastUrl: $pathname});

  // Figure out current page
  const pages = user.is('success') ? loggedInPages : loggedOutPages;
  const pageName = pages[pathParts.join('/')] ? pathParts.join('/') : pathParts[0];
  const nextPageComponent = pages[pageName];

  // Goto a valid page
  if (nextPageComponent) {
    if (nextPageComponent != pageComponent) pageComponent = nextPageComponent;
    $activeMenu = '';

    // Enable complex styling
    replaceBodyClassName(/(is-logged-)\S+/, user.is('success') ? 'in' : 'out');
    replaceBodyClassName(/(page-)\S+/, pageName.replace(/\W+/g, '_'));
  }
  else if (user.is('success')) {
    const lastUrl = user.lastUrl;
    gotoUrl(lastUrl || (user.connections.size ? '/chat' : '/add/connection'), {replace: true});
  }
  else if (user.is('error')) {
    gotoUrl('/login', {replace: true});
  }

  // Get list of emojis after logging in
  if (user.is('success')) loadScript('/images/emojis.js');

  // Remove original components
  if (pageComponent) {
    const removeEls = document.querySelectorAll('.js-remove');
    for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();
  }
}

function debugClick(e) {
  // This is useful if you want to see on server side what is being clicked on
  // user.events.send({method: 'debug', type: e.type, target: e.target.tagName, className: e.target.className});
}

function hideMenu(e) {
  if (closestEl(e.target, '.chat-header')) return;
  if (closestEl(e.target, '.sidebar-wrapper')) return;
  $activeMenu = '';
}

function onFocus(e) {
  user.events.ensureConnected();
}

function replaceBodyClassName(re, replacement) {
  const body = document.querySelector('body');
  body.className = body.className.replace(re, (all, prefix) => prefix + replacement);
}
</script>

<svelte:window on:focus="{onFocus}" on:click="{debugClick}" bind:innerWidth="{containerWidth}"/>
<svelte:component this="{pageComponent}"/>

<div class="overlay" class:is-visible="{$activeMenu && $container.small}">&nbsp;</div>
