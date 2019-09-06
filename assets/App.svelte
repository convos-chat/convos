<script>
import {gotoUrl, historyListener, pathParts} from './store/router';
import {onMount, setContext} from 'svelte';
import Api from './js/Api';
import User from './store/User';

// Pages
import Chat from './page/Chat.svelte';
import ConnectionCreate from './page/ConnectionCreate.svelte';
import Help from './page/Help.svelte';
import Join from './page/Join.svelte';
import Login from './page/Login.svelte';
import Register from './page/Register.svelte';
import Settings from './page/Settings.svelte';

// Routing
const pages = {
  'add/connection': ConnectionCreate,
  'add/conversation': Join,
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

$: currentPage = pages[$pathParts.join('/')] || pages[$pathParts[0]] || ($user.email ? pages.chat : pages.login);

const login = user.login;
$: if ($login.is('success')) {
  document.cookie = $user.login.res.headers['Set-Cookie'];
  user.login.reset();
  user.load();
  gotoUrl('/chat');
}

const logout = user.logout;
$: if ($logout.is('success')) {
  user.logout.reset();
  user.reset();
  gotoUrl('/');
}

onMount(async () => {
  await user.load();

  const historyUnlistener = historyListener();
  const removeEls = document.querySelectorAll('.js-remove');
  for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();

  return () => {
    historyUnlistener();
  };
});
</script>

<svelte:component this={currentPage}/>
