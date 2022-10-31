<script>
import Icon from '../components/Icon.svelte';
import {activeMenu} from '../store/viewport';
import {awayMessage} from '../js/chatHelpers';
import {l, lmd} from '../store/I18N';
import {modeClassNames} from '../js/util';

export let conversation;

$: participants = conversation.participants;

export function conversationJoin(e) {
  const aEl = e.target.closest('a');
  conversation.send('/join ' + decodeURIComponent(aEl.hash.replace(/^#?action:join:/, '')));
}
</script>

<div class="sidebar-right">
  <h3>{$l('Participants (%1)', $participants.length)}</h3>

  <nav class="sidebar-right__nav" on:click|preventDefault="{conversationJoin}">
    {#if $participants.length}
      {#each $participants.toArray() as participant}
        <a href="#action:join:{participant.nick}" class="participant {modeClassNames(participant.modes)}">
          <Icon name="pick:{participant.nick}" family="solid" color="{participant.color}"/>
          <span>{participant.nick}</span>
        </a>
      {/each}
    {:else}
      <a href="#settings" on:click="{activeMenu.toggle}"><Icon name="users-cog"/> {$l('Settings')}</a>
    {/if}
  </nav>

  {#if $conversation.is('private') && $conversation.info.nick}
    <h3>{$l('Information')}</h3>
    <p>{@html $lmd(...awayMessage($conversation.info))}</p>
  {/if}
</div>
