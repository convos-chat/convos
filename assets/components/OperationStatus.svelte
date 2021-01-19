<script>
import Operation from '../store/Operation';
import {l} from '../store/I18N';
import {onDestroy} from 'svelte';

export let progress = false;
export let op = new Operation({});

let pct = 0;
let tid;

$: calculateProgress($op, progress);

onDestroy(() => (tid && clearTimeout(tid)));

function calculateProgress($op, progress) {
  if (tid) clearTimeout(tid);
  if (!$op.is('loading')) return;
  if (typeof progress == 'number') return (pct = progress);
  pct = 0;
  tid = setInterval(() => (++pct), 500);
}
</script>

{#if $op.is('error')}
  <div class="error">{$l($op.error())}</div>
{:else if progress !== false && $op.is('loading')}
  <div class="progress">
    <div class="progress__bar" style="width:{pct}%;">{$l('Loading...')}</div>
  </div>
{/if}
