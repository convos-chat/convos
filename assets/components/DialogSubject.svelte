<script>
import {l} from '../js/i18n';
import {md} from '../js/md';

export let dialog = {};
</script>

{#if !dialog.connection_id}
  <!-- Waiting for dialog -->
{:else if dialog.frozen}
  {l(dialog.frozen)}
{:else if dialog.topic}
  {@html md(dialog.topic)}
{:else if dialog.state == 'disconnected'}
  {l('Disconnected.')}
{:else if dialog.is_private}
  {l('Private conversation.')}
{:else if dialog.dialog_id}
  {l('No topic is set.')}
{:else}
  {l('Connection messages.')}
{/if}
