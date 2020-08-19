<script>
import Icon from '../components/Icon.svelte';
import Time from '../js/Time';
import {l} from '../js/i18n';

export let same = false;
export let type = 'notice';

const hm = new Time().getHM();
</script>

<div class="message is-type-{type}">
  {#if !same}
    <Icon name="pick:Convos" color="inherit"/>
    <b class="message__ts">{hm}</b>
    <a href="/settings/account" class="message__from" color="inherit">{l('Convos')}</a>
  {/if}
  <div class="message__text"><slot/></div>
</div>
