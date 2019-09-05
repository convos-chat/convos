<script>
import {l} from '../js/i18n';
import {getContext, onMount, tick} from 'svelte';
import {md} from '../js/md';
import ChatHeader from '../components/ChatHeader.svelte';
import Link from '../components/Link.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
</script>

<SidebarChat/>

<main class="main">
  <ChatHeader>
    <h1>{l('Join conversation')}</h1>
  </ChatHeader>

  <p>TODO: {@html md('https://github.com/Nordaaker/convos/blob/3a612b1d2081e566caa33039c5b2642864c1903d/assets/vue/convos-create-dialog.vue')}</p>
  <ol>
    <li>Choose connection or use last active connection.</li>
    <li>Input field for searching. Stick to top?</li>
    <li>List of available channels. Infinite scroll?</li>
  </ol>
</main>
