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
$: replaceClassName('html', /(theme-)\S+/, $user.theme);
$: calculatePage($currentUrl, $getUserOp);
$: unread = $user.unread;
$: if (document) document.title = unread ? '(' + unread + ') ' + $docTitle : $docTitle;

currentUrl.base = settings.baseUrl;

setContext('settings', settings);
setContext('user', user);

window.addEventListener('error', ({colno, error, filename, lineno, message, type, timeStamp}) => {
  user.events.send({method: 'debug', type, colno, error, filename, lineno, message, timeStamp});
});

window.addEventListener('unhandledrejection', ({type, reason, returnValue, timeStamp}) => {
  user.events.send({method: 'debug', type, reason, returnValue, timeStamp});
});

onMount(() => {
  if (!settings.chatMode) return;

  const dialogEventUnlistener = user.on('dialogEvent', calculateNewPath);
  const historyUnlistener = historyListener();
  user.load();
  if (user.showGrid) document.querySelector('body').classList.add('with-grid');

  return () => {
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

function calculatePage($url, $getUserOp) {
  // Remember last chat
  if ($url.pathParts[0] == 'chat') user.update({lastUrl: $url.toString()});

  // Figure out current page
  const loggedIn = $getUserOp.is('success');
  const pages = loggedIn ? loggedInPages : loggedOutPages;
  const pageName = pages[$url.path] ? $url.path : $url.pathParts[0] || '';
  const nextPageComponent = pages[pageName];

  if (loggedIn && settings.conn_url) {
    return (location.href = currentUrl.base + '/register?uri=' + encodeURIComponent(settings.conn_url));
  }

  if (loggedIn) {
    loadScript(currentUrl.base + '/images/emojis.js');
  }

  // Goto a valid page
  if (nextPageComponent) {
    if (nextPageComponent != pageComponent) pageComponent = nextPageComponent;

    // Enable complex styling
    replaceClassName('body', /(is-logged-)\S+/, loggedIn ? 'in' : 'out');
    replaceClassName('body', /(page-)\S+/, pageName.replace(/\W+/g, '_') || 'loading');
  }
  else if (loggedIn) {
    const lastUrl = user.lastUrl;
    gotoUrl(lastUrl || (user.connections.size ? '/chat' : '/add/connection'), {replace: true});
  }
  else if ($getUserOp.is('error')) {
    gotoUrl('/login', {replace: true});
  }

  // Remove original components
  const removeEls = document.querySelectorAll('.js-remove');
  for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();
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
  // user.events.send({method: 'debug', type: e.type, target: e.target.tagName, className: e.target.className});

  const linkEl = closestEl(e.target, 'a');
  const action = linkEl && linkEl.href.match(/#(call:user):(\w+)/) || ['', '', ''];
  if (action[2]) {
    e.preventDefault();
    user[action[2]]();
    return;
  }

  if (closestEl(e.target, '.sidebar-left') && !linkEl) {
    return;
  }

  const toggle = linkEl && linkEl.href.match(/#(activeMenu):(\w*)/) || ['', '', ''];
  if (toggle[1] || $activeMenu) e.preventDefault();
  $activeMenu = toggle[2] == $activeMenu ? '' : toggle[2];
}

function onWindowFocus() {
  if (settings.chatMode) user.events.ensureConnected();
}

function replaceClassName(sel, re, replacement) {
  const tag = document.querySelector(sel);
  tag.className = tag.className.replace(re, (all, prefix) => prefix + replacement);
}
</script>

<svelte:window
  on:click="{onWindowClick}"
  on:focus="{onWindowFocus}"
  on:keydown="{onGlobalKeydown}"
  bind:innerWidth="{containerWidth}"/>

<svelte:component this="{pageComponent}"/>

{#if $activeMenu && $container.small}
  <div class="overlay" transition:fade="{{duration: 200}}">&nbsp;</div>
{/if}
