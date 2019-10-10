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
const connections = user.connections;
const notifications = user.notifications;
const loginOp = user.loginOp;

setContext('embedMaker', embedMaker);
setContext('user', user);

$: if (document) document.title = $notifications.unread ? '(' + $notifications.unread + ') ' + $docTitle : $docTitle;
$: currentPage = pages[$pathParts.join('/')] || pages[$pathParts[0]];
$: $pathname.indexOf('/chat') != -1 && localStorage.setItem('lastUrl', $pathname);

$: if ($user.is('success')) gotoDefaultPage();
$: if ($user.is('error') || $loginOp.is('error')) gotoUrl('/login', {replace: true});

$: if ($loginOp.is('success')) {
  document.cookie = loginOp.res.headers['Set-Cookie'];
  loginOp.reset();
  user.load();
}

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
  const lastUrl = localStorage.getItem('lastUrl');
  gotoUrl(lastUrl || ($connections.length ? '/chat' : '/add/connection'), {replace: true});
}
</script>

<svelte:component this="{currentPage}"/>

<div class="overlay" class:is-visible="{$activeMenu}">&nbsp;</div>
