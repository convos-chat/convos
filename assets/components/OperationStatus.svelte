<script>
import Operation from '../store/Operation';
import {fade} from 'svelte/transition';
import {is} from '../js/util';
import {l} from '../store/I18N';
import {onDestroy} from 'svelte';

export let progress = false;
export let op = new Operation({});
export let success = 'Saved.';

let pct = 0;
let showSuccess = false;
let tid;

$: calculateProgress($op, progress);
$: showSuccessMessage($op);

onDestroy(() => (tid && clearTimeout(tid)));

function calculateProgress($op, progress) {
  if (tid) clearTimeout(tid);
  if (!$op.is('loading')) return;
  if (is.number(progress)) return (pct = progress);
  pct = 0;
  tid = setInterval(() => (++pct), 500);
}

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
{:else if progress !== false && $op.is('loading')}
  <div class="progress">
    <div class="progress__bar" style="width:{pct}%;">{$l('Loading...')}</div>
  </div>
{/if}
