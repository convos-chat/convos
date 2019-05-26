<script>
import {Api} from './js/Api';
import {getUser} from './store/user';
import {historyListener, pathParts} from './store/router';
import {onMount, setContext} from 'svelte';
import Chat from './page/Chat.svelte';
import Connections from './page/Connections.svelte';
import Help from './page/Help.svelte';
import Join from './page/Join.svelte';
import Login from './page/Login.svelte';
import Register from './page/Register.svelte';
import Settings from './page/Settings.svelte';

const api = new Api('/api.json', {debug: true});
setContext('api', api);

// Routing
let currentPage = undefined;
const pages = {
  chat: Chat,
  connections: Connections,
  help: Help,
  join: Join,
  login: Login,
  register: Register,
  settings: Settings,
}

pathParts.subscribe($pathParts => {
  currentPage = pages[$pathParts[0]] || pages.login;
});

onMount(() => {
  const historyUnlistener = historyListener();
  getUser(api);

  return () => {
    historyUnlistener();
  };
});
</script>

<svelte:component this={currentPage}/>
