<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import Unread from './Unread.svelte';
import {activeMenu} from '../store/router';
import {l} from '../js/i18n';

export let dialog = {name: ''};
export let href = false;
export let icon = 'cog';

const classNames = ['sidebar__item'];

$: if (dialog.connection_id) classNames.push('has-settings');
$: if (dialog.connection_id && !dialog.dialog_id) classNames.push('for-connection');
$: if (dialog.dialog_id) classNames.push('for-dialog');
$: if (dialog.frozen) classNames.push('is-frozen');

$: settingsIcon = !dialog.connection_id ? null
                : !dialog.dialog_id     ? 'network-wired'
                : dialog.is('private')  ? 'user'
                :                         'user-friends';

function clicked(e) {
  const aEl = e.target.closest('a');
  if (aEl && aEl.classList.contains('sidebar__item__link')) $activeMenu = '';
}

</script>

<div class="{classNames.join(' ')}" on:click="{clicked}">
  {#if settingsIcon}
    <Link href="/chat/{dialog.path}#settings" class="sidebar__item__settings">
      <Icon name="{settingsIcon}"/>
    </Link>
  {/if}
  {#if href}
    <Link href="{href}" class="sidebar__item__link">
      <Icon name="{icon}"/>
      <slot/>
    </Link>
  {:else}
    <Link href="/chat/{dialog.path}" class="sidebar__item__link">
      <span>{l(dialog.name.replace(/^\W/, ''))}</span>
      <Unread unread="{dialog.unread}"/>
    </Link>
  {/if}
</div>
