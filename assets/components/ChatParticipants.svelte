<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {afterUpdate, getContext} from 'svelte';
import {modeClassNames, q} from '../js/util';
import {l} from '../store/I18N';

const user = getContext('user');

export let conversation;

$: connection = user.findConversation({connection_id: conversation.connection_id});

function joinConversation(e, participant) {
  e.preventDefault();
  conversation.send('/join ' + participant.id);
}
</script>

{#if conversation.participants().length}
  <div class="sidebar-right">
    <nav class="sidebar-right__nav">
      <h3>{$l('Participants (%1)', conversation.participants().length)}</h3>
      {#each conversation.participants() as participant}
        <Link href="/chat/{conversation.connection_id}/{participant.id}" on:click="{e => joinConversation(e, participant)}" class="participant {modeClassNames(participant.modes)}">
          <Icon name="pick:{participant.id}" family="solid" color="{participant.color}"/>
          <span>{participant.nick}</span>
        </Link>
      {/each}
    <nav>
  </div>
{/if}
