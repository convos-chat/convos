<script>
import Icon from '../components/Icon.svelte';
import {l, lmd} from '../store/I18N';

export let conversation;

$: participants = conversation.participants;
</script>

{#if $conversation.is('private')}
  <p><Icon name="info-circle"/> {@html $lmd('This is a private conversation with "%1".', $conversation.name)}</p>
{:else if !$conversation.frozen}
  <p>
    <Icon name="info-circle"/>
    {@html $lmd($conversation.topic ? 'Topic for %1 is: %2': 'No topic is set for %1.', $conversation.name, $conversation.topic)}
  </p>
  <p>
    <Icon name="info-circle"/>
    {#if $participants.length === 1}
      {$l('You are the only participant in this conversation.')}
    {:else}
      {@html $lmd('There are %1 participants in this conversation.', $participants.length)}
    {/if}
  </p>
{/if}
