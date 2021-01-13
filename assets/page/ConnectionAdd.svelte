<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ConnectionForm from '../components/ConnectionForm.svelte';
import {getContext} from 'svelte';
import {route} from '../store/Route';
import {viewport} from '../store/Viewport';

$: l = $viewport.l;

route.update({title: 'Add connection'});
</script>

<ChatHeader>
  <h1>{l('Add connection')}</h1>
</ChatHeader>

<main class="main">
  <ConnectionForm/>
</main>
