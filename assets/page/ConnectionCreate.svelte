<script>
import {l} from '../js/i18n';
import ChatHeader from '../components/ChatHeader.svelte';
import ConnectionForm from '../components/ConnectionForm.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
</script>

<SidebarChat/>

<main class="main">
  <ChatHeader>
    <h1>{l('Add connection')}</h1>
  </ChatHeader>
  <ConnectionForm/>
</main>
