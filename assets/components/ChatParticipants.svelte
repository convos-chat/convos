<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {modeClassNames} from '../js/util';
import {l} from '../store/I18N';

export let conversation;

$: participants = conversation.participants;

function joinConversation(e, participant) {
  e.preventDefault();
  conversation.send('/join ' + participant.id);
}
</script>

{#if $participants.length}
  <div class="sidebar-right">
    <nav class="sidebar-right__nav">
      <h3>{$l('Participants (%1)', participants.length)}</h3>
      {#each $participants.toArray() as participant}
        <Link href="/chat/{conversation.connection_id}/{participant.id}" on:click="{e => joinConversation(e, participant)}" class="participant {modeClassNames(participant.modes)}">
          <Icon name="pick:{participant.id}" family="solid" color="{participant.color}"/>
          <span>{participant.nick}</span>
        </Link>
      {/each}
    <nav>
  </div>
{/if}
