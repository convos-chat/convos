<script>
import {l} from '../js/i18n';
import {md} from '../js/md';

export let dialog = {};
</script>

{#if !dialog || !dialog.id}
  <!-- Waiting for dialog -->
{:else if dialog.frozen}
  {l(dialog.frozen)}
{:else if dialog.topic}
  {md(dialog.topic)}
{:else if dialog.state == 'disconnected'}
  {l('Disconnected.')}
{:else if dialog.is_private}
  {l('Private conversation.')}
{:else if dialog.isConnection}
  {l('Server messages.')}
{:else}
  {l('No topic is set.')}
{/if}
