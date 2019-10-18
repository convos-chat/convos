<script>
import Api from './js/Api';
import EmbedMaker from './js/EmbedMaker';
import User from './store/User';
import {activeMenu, docTitle, gotoUrl, historyListener, pathname, pathParts} from './store/router';
import {onMount, setContext} from 'svelte';

// Pages
import Chat from './page/Chat.svelte';
import ConnectionAdd from './page/ConnectionAdd.svelte';
import DialogAdd from './page/DialogAdd.svelte';
import Help from './page/Help.svelte';
import Login from './page/Login.svelte';
import Register from './page/Register.svelte';
import Settings from './page/Settings.svelte';

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

const Convos = window.Convos || {};
const api = new Api(Convos.apiUrl, {debug: true});
const embedMaker = new EmbedMaker({api});
const user = new User({api});
const notifications = user.notifications;

let pageComponent = null;

$: if (document) document.title = $notifications.unread ? '(' + $notifications.unread + ') ' + $docTitle : $docTitle;
$: calculatePage($pathParts, $user);

setContext('embedMaker', embedMaker);
setContext('user', user);

onMount(async () => {
  const dialogEventUnlistener = user.on('dialogEvent', calculateNewPath);
  const historyUnlistener = historyListener();
  user.load();

  return () => {
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
  if (pathParts.indexOf('chat') != -1) localStorage.setItem('lastUrl', $pathname);

  // Figure out current page
  const pages = user.is('success') ? loggedInPages : loggedOutPages;
  const nextPageComponent = pages[pathParts.join('/')] || pages[pathParts[0]];

  // Goto a valid page
  if (nextPageComponent) {
    if (nextPageComponent != pageComponent) pageComponent = nextPageComponent;

    // Enable complex styling
    replaceBodyClassName(/(is-logged-)\S+/, user.is('success') ? 'in' : 'out');
    replaceBodyClassName(/(page-)\S+/, pathParts.join('_').replace(/\W+/g, '_'));
  }
  else if (user.is('success')) {
    const lastUrl = localStorage.getItem('lastUrl');
    gotoUrl(lastUrl || (user.connections.size ? '/chat' : '/add/connection'), {replace: true});
  }
  else if (user.is('error')) {
    gotoUrl('/login', {replace: true});
  }

  // Remove original components
  if (pageComponent) {
    const removeEls = document.querySelectorAll('.js-remove');
    for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();
  }
}

function replaceBodyClassName(re, replacement) {
  const body = document.querySelector('body');
  body.className = body.className.replace(re, (all, prefix) => prefix + replacement);
}
</script>

<svelte:component this="{pageComponent}"/>

<div class="overlay" class:is-visible="{$activeMenu}">&nbsp;</div>
