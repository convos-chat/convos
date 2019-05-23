<script>
import {historyListener, pathParts} from './store/router';
import {onMount} from 'svelte';
import Login from './components/Login.svelte';

let currentPage = Login;

pathParts.subscribe($pathParts => {
  currentPage = $pathParts ? Login : null; // TODO: Change currentPage based on $pathParts[0]
});

onMount(() => {
  const historyUnlistener = historyListener();

  return () => {
    historyUnlistener();
  };
});
</script>

<svelte:component this={currentPage}/>
