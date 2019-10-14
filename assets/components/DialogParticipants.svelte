<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {l} from '../js/i18n';

export let dialog;

function participantClassNames(str) {
  return (str || '').split('').map(m => { return 'has-mode-' + m }).join(' ');
}
</script>

{#if dialog.participants.length}
  {#each dialog.participants as participant}
    <Link href="/chat/{dialog.connection_id}/{participant.id}" className="participant {participantClassNames(participant.mode)}">
      <Icon name="random:{participant.id}" family="solid" style="color:{participant.color}"/>
      <span>{participant.nick}</span>
    </Link>
  {/each}
{:else}
  <p>{l('No participants.')}</p>
{/if}
