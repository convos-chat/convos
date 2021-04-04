<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ConnectionForm from '../components/ConnectionForm.svelte';
import ConnectionProfiles from '../components/ConnectionProfiles.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {l} from '../store/I18N';
import {getContext} from 'svelte';

export const title = 'Connections';

let editProfile = null;
</script>

<ChatHeader>
  <h1>{editProfile ? $l('Connection profile', editProfile.id) : $l('Connections')}</h1>
  <Link href="/settings/connections" class="btn-hallow {editProfile ? 'is-active' : ''}" data-tooltip="{$l('See all profiles')}"><Icon name="list"/><Icon name="times"/></Link>
</ChatHeader>

<main class="main">
  {#if !editProfile}
    <h2>{$l('Add connection')}</h2>
    <ConnectionForm/>
  {/if}

  <ConnectionProfiles bind:editProfile="{editProfile}"/>
</main>
