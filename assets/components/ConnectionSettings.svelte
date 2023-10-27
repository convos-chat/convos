<script>
import ChatParticipants from '../components/ChatParticipants.svelte';
import ConnectionForm from './ConnectionForm.svelte';
import {activeMenu, viewport} from '../store/viewport';
import {fly} from 'svelte/transition';
import {getContext, onMount} from 'svelte';
import {l} from '../store/I18N';

export let conversation = {};

const user = getContext('user');

let connection = {};

$: connectionHost = connection.real_host || connection.url && connection.url.host;

onMount(async () => {
  connection = user.findConversation({connection_id: conversation.connection_id}) || {};
});
</script>

{#if $viewport.hasRightColumn || $activeMenu === 'settings'}
  <div transition:fly="{$viewport.sidebarTransition}"
    class:sidebar-left={!$viewport.hasRightColumn}
    class:sidebar-right={$viewport.hasRightColumn}>
    <h3>{$l('Settings')}</h3>

    {#if !connection.url}
      <p>{$l('Connection not found.')}</p>
    {:else if connection.state === 'disconnected'}
      <p>{$l('Currently disconnected from %1.', connectionHost)}</p>
    {:else if connection.state === 'connected'}
      <p>{$l('Currently connected to %1.', connectionHost)}</p>
    {:else}
      <p>{$l('Currently connecting to %1.', connectionHost)}</p>
    {/if}

    <ConnectionForm id="{conversation.connection_id}"/>
    <ChatParticipants conversation="{conversation}"/>
  </div>
{/if}
