<script>
import Icon from '../components/Icon.svelte';
import Time from '../js/Time';
import {l} from '../js/i18n';

const hm = new Time().getHM();
</script>

<div class="message is-type-notice">
  <Icon name="pick:Convos" color="inherit"/>
  <b class="message__ts">{hm}</b>
  <a href="/settings/account" class="message__from" color="inherit">{l('Convos')}</a>
  <div class="message__text"><slot/></div>
</div>
