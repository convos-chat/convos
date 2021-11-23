<script>
import {l} from '../store/I18N';

export let colspan = 1;
export let op;
</script>

<tr>
  <td colspan="{colspan}">
    {#if $op.is('error')}
      <div class="error">{$l($op.error())}</div>
    {:else if $op.is('loading')}
      {$l('Loading...')}
    {:else}
      <slot/>
    {/if}
  </td>
</tr>
