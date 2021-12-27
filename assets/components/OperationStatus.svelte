<script>
import Operation from '../store/Operation';
import {fade} from 'svelte/transition';
import {l} from '../store/I18N';
import {onDestroy} from 'svelte';

export let op = new Operation({});
export let success = 'Saved.';

let showSuccess = false;
let tid;

$: showSuccessMessage($op);

onDestroy(() => (tid && clearTimeout(tid)));

function showSuccessMessage($op) {
  if (!$op.is('success')) return (showSuccess = false);
  if (showSuccess) return;
  showSuccess = true;
  tid = setTimeout(() => (showSuccess = false), 2000);
}
</script>

{#if $op.is('error')}
  <div class="error" transition:fade>{$l($op.error())}</div>
{:else if $op.is('success') && showSuccess}
  <div class="success" transition:fade>{$l(success)}</div>
{/if}
