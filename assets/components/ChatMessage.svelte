<script>
import Icon from '../components/Icon.svelte';
import Time from '../js/Time';
import {l} from '../store/I18N';

export let same = false;
export let type = 'notice';

const now = new Time();
</script>

<div class="message is-type-{type}">
  {#if !same}
    <Icon name="pick:Convos" color="inherit"/>
    <b class="message__ts">{now.format('%H:%M')}</b>
    <a href="/settings/account" class="message__from" color="inherit">{$l('Convos')}</a>
  {/if}
  <div class="message__text"><slot/></div>
</div>
