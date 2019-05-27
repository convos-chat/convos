<script>
import {l} from '../js/i18n';
import {md} from '../js/md';

export let obj;
</script>

{#if !obj || !obj.connection_id}
  <!-- Waiting for dialog -->
{:else if obj.frozen}
  {l(obj.frozen)}
{:else if obj.topic}
  {md(obj.topic)}
{:else if obj.state == 'disconnected'}
  {l('Disconnected.')}
{:else if obj.is_private}
  {l('Private conversation.')}
{:else if !obj.dialog_id}
  {l('Server messages.')}
{:else}
  {l('No topic is set.')}
{/if}