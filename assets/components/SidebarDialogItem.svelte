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
  if (dialog.connection_id && !dialog.dialog_id) cn.push('for-connection');
  if (dialog.dialog_id) cn.push('for-dialog');
  if (dialog.frozen || connection.state != 'connected') cn.push('is-frozen');
  return cn;
}

function onClick(e) {
  if (e.target.classList.contains('fa')) setTimeout(() => { $activeMenu = 'settings' }, 50);
}
</script>

<div class="sidebar__item {classNames.join(' ')}" title="{topicOrStatus(connection, dialog)}" on:click="{onClick}">
  <Link href="{dialog.path}" class="sidebar__item__link">
    <Icon name="{settingsIcon}"/>
    <span>{dialog.name}</span>
    <Unread unread="{dialog.unread}"/>
  </Link>
</div>
