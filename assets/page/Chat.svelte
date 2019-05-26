<script>
import {getContext, onMount, tick} from 'svelte';
import {md} from '../js/md';
import {pathParts} from '../store/router';
import Link from '../components/Link.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import Ts from '../components/Ts.svelte';

const api = getContext('api');
let height = 0;
let messages = [];
let scrollDirection = 'down'; // TODO: Change it to up, when scrolling up
let subject = 'Some cool subject'; // TODO: Get it from Api

pathParts.subscribe(async ($pathParts) => {
  const res = await api.execute('dialogMessages', {
    connection_id: $pathParts[1] || '',
    dialog_id: $pathParts[2] || '',
  });

  messages = res.messages || [];
});

$: if (scrollDirection == 'down') window.scrollTo(0, height);
</script>

<SidebarChat/>

<main class="main-app-pane" bind:offsetHeight="{height}">
  <h1 class="main-header">
    <span>{decodeURIComponent($pathParts[2] || $pathParts[1])}</span>
    <small>{subject || 'No subject.'}</small>
  </h1>
  {#each messages as message}
    <div class="message" class:is-hightlight="{message.highlight}">
      <Ts val="{message.ts}"/>
      <Link className="message_link" href="/chat/{$pathParts[1]}/{message.from}">{message.from}</Link>
      <div class="message_text">{@html md(message.message)}</div>
    </div>
  {/each}
</main>