<script>
import {l} from '../js/i18n';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import Unread from './Unread.svelte';

export let dialog = {};
export let href = false;
export let icon = 'cog';

const classNames = ['sidebar__item'];
if (dialog.dialog_id) classNames.push('for-dialog');
if (dialog.connection_id) classNames.push('has-settings');

$: settingsIcon = !dialog.connection_id ? null
                : !dialog.dialog_id     ? 'network-wired'
                : dialog.is_private     ? 'user'
                :                         'user-friends';
</script>

<div class={classNames.join(' ')}>
  {#if settingsIcon}
    <Link href="/chat/{dialog.path}#settings" className="sidebar__item__settings">
      <Icon name="{settingsIcon}"/>
    </Link>
  {/if}
  {#if href}
    <Link href="{href}" className="sidebar__item__link">
      <Icon name="{icon}"/>
      <slot/>
    </Link>
  {:else}
    <Link href="/chat/{dialog.path}" className="sidebar__item__link">
      <span>{l(dialog.name.replace(/^\W/, ''))}</span>
      <Unread unread="{dialog.unread}"/>
    </Link>
  {/if}
</div>
