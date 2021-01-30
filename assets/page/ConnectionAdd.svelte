<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ConnectionForm from '../components/ConnectionForm.svelte';
import {l} from '../store/I18N';

export const title = 'Add connection';
</script>

<ChatHeader>
  <h1>{$l('Add connection')}</h1>
</ChatHeader>

<main class="main">
  <ConnectionForm/>
</main>
