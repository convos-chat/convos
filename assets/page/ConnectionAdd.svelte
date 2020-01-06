<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ConnectionForm from '../components/ConnectionForm.svelte';
import {l} from '../js/i18n';
import {docTitle} from '../store/router';

$docTitle = l('%1 - Convos', l('Add connection'));
</script>

<ChatHeader>
  <h1>{l('Add connection')}</h1>
</ChatHeader>

<main class="main">
  <ConnectionForm/>
</main>
