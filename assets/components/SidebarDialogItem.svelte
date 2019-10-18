<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import Unread from './Unread.svelte';
import {activeMenu} from '../store/router';
import {topicOrStatus} from '../js/i18n';

export let connection;
export let dialog;

$: classNames = calculateClassNames(dialog);
$: settingsIcon = !dialog.connection_id ? null
                : !dialog.dialog_id     ? 'network-wired'
                : dialog.is('private')  ? 'user'
                :                         'user-friends';

function calculateClassNames(dialog) {
  const cn = [];
  if (dialog.connection_id) cn.push('has-settings');
  if (dialog.connection_id && !dialog.dialog_id) cn.push('for-connection');
  if (dialog.dialog_id) cn.push('for-dialog');
  if (dialog.frozen || connection.state != 'connected') cn.push('is-frozen');
  return cn;
}

function clicked(e) {
  const aEl = e.target.closest('a');
  if (aEl && aEl.classList.contains('sidebar__item__link')) $activeMenu = '';
}
</script>

<div class="sidebar__item {classNames.join(' ')}" on:click="{clicked}" title="{topicOrStatus(connection, dialog)}">
  <Link href="/chat/{dialog.path}#settings" class="sidebar__item__settings">
    <Icon name="{settingsIcon}"/>
  </Link>
  <Link href="/chat/{dialog.path}" class="sidebar__item__link">
    <span>{dialog.name}</span>
    <Unread unread="{dialog.unread}"/>
  </Link>
</div>
