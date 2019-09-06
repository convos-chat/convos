<script>
import {l} from '../js/i18n';
import Operation from '../store/Operation';

export let op = new Operation({});
</script>

{#if $op.is('error')}
  <div class="error">{l($op.error())}</div>
{/if}
