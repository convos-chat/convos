<script>
import {getUser} from '../store/user';
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

onMount(() => getUser(api));
</script>

<SidebarChat/>

<main class="messages next-to-sidebar" bind:offsetHeight="{height}">
  <h1 class="messages_subject">
    <span>{decodeURIComponent($pathParts[2] || $pathParts[1])}</span>
    <small class:has-subject="{subject.length > 0}">{subject}</small>
  </h1>
  {#each messages as message}
    <div class="messages_message" class:is-hightlight="{message.highlight}">
      <Ts val="{message.ts}"/>
      <Link href="/chat/{$pathParts[1]}/{message.from}">{message.from}</Link>
      <div>{@html md(message.message)}</div>
    </div>
  {/each}
</main>