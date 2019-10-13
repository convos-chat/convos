<script>
import {activeMenu, docTitle, gotoUrl, historyListener, pathname, pathParts} from './store/router';
import {onMount, setContext} from 'svelte';
import Api from './js/Api';
import EmbedMaker from './js/EmbedMaker';
import User from './store/User';

// Pages
import Chat from './page/Chat.svelte';
import ConnectionAdd from './page/ConnectionAdd.svelte';
import DialogAdd from './page/DialogAdd.svelte';
import Help from './page/Help.svelte';
import Login from './page/Login.svelte';
import Register from './page/Register.svelte';
import Settings from './page/Settings.svelte';

// Routing
const pages = {
  'add/connection': ConnectionAdd,
  'add/conversation': DialogAdd,
  chat: Chat,
  help: Help,
  login: Login,
  register: Register,
  settings: Settings,
};

const Convos = window.Convos || {};
const api = new Api(Convos.apiUrl, {debug: true});
const embedMaker = new EmbedMaker({api});
const user = new User({api});
const notifications = user.notifications;
const loginOp = user.loginOp;

setContext('embedMaker', embedMaker);
setContext('user', user);

$: defaultPageName = $user.is('success') ? 'chat' : 'login';
$: pageName = pages[$pathParts.join('/')] ? $pathParts.join('/') : $pathParts[0] || defaultPageName;
$: $pathname.indexOf('/chat') != -1 && localStorage.setItem('lastUrl', $pathname);

$: if (document) document.title = $notifications.unread ? '(' + $notifications.unread + ') ' + $docTitle : $docTitle;
$: if ($user.is('success')) gotoDefaultPage();
$: if ($user.is('error') || $loginOp.is('error')) gotoUrl('/login', {replace: true});

$: if ($loginOp.is('success')) {
  document.cookie = loginOp.res.headers['Set-Cookie'];
  loginOp.reset();
  user.load();
}

$: if ($user) replaceBodyClassName(/(is-logged-)\S+/, $user.is('success') ? 'in' : 'out');
$: if ($user) replaceBodyClassName(/(page-)\S+/, pageName.replace(/\W+/g, '_'));

onMount(async () => {
  const historyUnlistener = historyListener();

  const removeEls = document.querySelectorAll('.js-remove');
  for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();

  user.load();

  return () => {
    historyUnlistener();
  };
});

function gotoDefaultPage() {
  if (location.href.indexOf('/chat') != -1) return;
  const lastUrl = localStorage.getItem('lastUrl');
  gotoUrl(lastUrl || (user.connections.length ? '/chat' : '/add/connection'), {replace: true});
}

function replaceBodyClassName(re, replacement) {
  const body = document.querySelector('body');
  body.className = body.className.replace(re, (all, prefix) => prefix + replacement);
}
</script>

<svelte:component this="{pages[pageName]}"/>

<div class="overlay" class:is-visible="{$activeMenu}">&nbsp;</div>
