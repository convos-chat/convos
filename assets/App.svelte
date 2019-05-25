<script>
import {Api} from './js/Api';
import {historyListener, pathParts} from './store/router';
import {onMount, setContext} from 'svelte';
import Login from './page/Login.svelte';
import Register from './page/Register.svelte';

setContext('api', new Api('/api.json'));

// Routing
let currentPage = undefined;
pathParts.subscribe($pathParts => {
  if ($pathParts[0] == 'register') {
    return (currentPage = Register);
  }
  else {
    return (currentPage = Login);
  }
});

onMount(() => {
  const historyUnlistener = historyListener();

  return () => {
    historyUnlistener();
  };
});
</script>

<svelte:component this={currentPage}/>
