<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ConnectionProfiles from '../components/ConnectionProfiles.svelte';
import Connections from '../components/Connections.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {l} from '../store/I18N';
import {getContext} from 'svelte';

export const title = 'Connections';

let editConnection = null;
let editProfile = null;
</script>

<ChatHeader>
  <h1>{editConnection ? $l('Connection') : editProfile ? $l('Connection profile', editProfile.id) : $l('Connections')}</h1>
  <Link href="/settings/connections" class="btn-hallow {editConnection || editProfile ? 'is-active' : ''}" data-tooltip="{$l('See all profiles')}"><Icon name="list"/><Icon name="times"/></Link>
</ChatHeader>

<main class="main">
  {#if !editProfile}
    <Connections bind:editConnection="{editConnection}"/>
  {/if}
  {#if !editConnection}
    <ConnectionProfiles bind:editProfile="{editProfile}"/>
  {/if}
</main>
