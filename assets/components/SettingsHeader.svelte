<script>
import Icon from '../components/Icon.svelte';
import {l} from '../js/i18n';

export let dialog = {};
</script>

<a href="#activeMenu:" class="sidebar__header for-settings">
  <h2>{l(dialog.dialog_id ? 'Conversation' : 'Connection')}</h2>
  <Icon name="times-circle"/>
</a>
