<script>
import {gotoUrl, historyListener, pathname, pathParts} from './store/router';
import {onMount, setContext} from 'svelte';
import Api from './js/Api';
import User from './store/User';

// Pages
import Chat from './page/Chat.svelte';
import ConnectionCreate from './page/ConnectionCreate.svelte';
import ConversationAdd from './page/ConversationAdd.svelte';
import Help from './page/Help.svelte';
import Login from './page/Login.svelte';
import Register from './page/Register.svelte';
import Settings from './page/Settings.svelte';

// Routing
const pages = {
  'add/connection': ConnectionCreate,
  'add/conversation': ConversationAdd,
  chat: Chat,
  help: Help,
  login: Login,
  register: Register,
  settings: Settings,
};

const Convos = window.Convos || {};
const api = new Api(Convos.apiUrl, {debug: true});
const user = new User({api, wsUrl: Convos.wsUrl});
setContext('user', user);

$: currentPage = pages[$pathParts.join('/')] || pages[$pathParts[0]];
$: $pathname.indexOf('/chat') != -1 && localStorage.setItem('lastUrl', $pathname);

const login = user.login;
$: if ($login.is('success')) {
  document.cookie = $user.login.res.headers['Set-Cookie'];
  user.login.reset();
  user.load().then(gotoDefaultPage);
}

const logout = user.logout;
$: if ($logout.is('success')) {
  user.logout.reset();
  user.reset();
  gotoUrl('/');
}

function gotoDefaultPage() {
  const lastUrl = localStorage.getItem('lastUrl');
  gotoUrl(lastUrl || (user.connections.length ? '/chat' : '/add/connection'));
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
</script>

<svelte:component this={currentPage}/>
