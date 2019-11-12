<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ConnectionForm from '../components/ConnectionForm.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import {l} from '../js/i18n';
import {sidebarSettings} from '../store/router';
</script>

{#if $sidebarSettings.show == 'nav' || $sidebarSettings.wideScreen}
  <SidebarChat transition="{$sidebarSettings.transition}"/>
{/if}

<ChatHeader>
  <h1>{l('Add connection')}</h1>
</ChatHeader>

<main class="main">
  <ConnectionForm/>
</main>
