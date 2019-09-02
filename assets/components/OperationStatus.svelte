<script>
import {l} from '../js/i18n';
import Operation from '../store/Operation';

export let op = new Operation({});
</script>

{#if $op.is('loading')}
  <slot name="loading"><div class="loading">{l('Loading...')}</div></slot>
{:else if $op.is('error')}
  <slot name="error"><div class="error">{l($op.error())}</div></slot>
{:else if $op.is('pending')}
  <slot name="pending"></slot>
{:else}
  <slot name="success"><div class="loading">{l('Done.')}</div></slot>
{/if}
