<script>
import {gotoUrl, historyListener, pathParts} from './store/router';
import {onMount, setContext} from 'svelte';
import Api from './js/Api';
import User from './store/User';

// Pages
import Chat from './page/Chat.svelte';
import Connections from './page/Connections.svelte';
import Help from './page/Help.svelte';
import Join from './page/Join.svelte';
import Login from './page/Login.svelte';
import Register from './page/Register.svelte';
import Settings from './page/Settings.svelte';

// Routing
const pages = {
  chat: Chat,
  connections: Connections,
  help: Help,
  join: Join,
  login: Login,
  register: Register,
  settings: Settings,
};

const Convos = window.Convos || {};
const api = new Api(Convos.apiUrl, {debug: true});
const user = new User({api, wsUrl: Convos.wsUrl});
setContext('user', user);

$: currentPage = pages[$pathParts[0]] || ($user.email ? pages.chat : pages.login);

const login = user.login;
$: if ($login.is('success')) {
  document.cookie = $user.login.res.headers['Set-Cookie'];
  user.login.reset();
  user.perform();
  gotoUrl('/chat');
}

const logout = user.logout;
$: if ($logout.is('success')) {
  user.logout.reset();
  user.reset();
  gotoUrl('/');
}

onMount(async () => {
  await user.perform();

  const historyUnlistener = historyListener();
  const removeEls = document.querySelectorAll('.js-remove');
  for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();

  return () => {
    historyUnlistener();
  };
});
</script>

<svelte:component this={currentPage}/>