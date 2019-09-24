<script>
import {gotoUrl, historyListener, pathname, pathParts} from './store/router';
import {onMount, setContext} from 'svelte';
import Api from './js/Api';
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
const user = new User({api});
const connections = user.connections;
const loginOp = user.loginOp;
const logoutOp = user.logoutOp;

setContext('user', user);

$: currentPage = pages[$pathParts.join('/')] || pages[$pathParts[0]];
$: $pathname.indexOf('/chat') != -1 && localStorage.setItem('lastUrl', $pathname);

$: if ($loginOp.is('success')) {
  document.cookie = loginOp.res.headers['Set-Cookie'];
  loginOp.reset();
  user.load().then(gotoDefaultPage);
}

$: if ($logoutOp.is('success')) {
  logoutOp.reset();
  user.reset();
  gotoUrl('/');
}

onMount(async () => {
  await user.load();
  if (!currentPage) gotoDefaultPage();

  const historyUnlistener = historyListener();
  const removeEls = document.querySelectorAll('.js-remove');
  for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();

  return () => {
    historyUnlistener();
  };
});

function gotoDefaultPage() {
  const lastUrl = localStorage.getItem('lastUrl');
  gotoUrl(lastUrl || ($connections.length ? '/chat' : '/add/connection'));
}
</script>

<svelte:component this="{currentPage}"/>
