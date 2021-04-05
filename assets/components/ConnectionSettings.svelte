<script>
import ConnectionForm from './ConnectionForm.svelte';
import Icon from './Icon.svelte';
import {activeMenu} from '../store/writable';
import {fly} from 'svelte/transition';
import {getContext, onMount} from 'svelte';
import {l} from '../store/I18N';

export let conversation = {};
export let transition;

const user = getContext('user');

let connection = {};

$: connectionHost = connection.real_host || connection.url && connection.url.host;

onMount(async () => {
  connection = user.findConversation({connection_id: conversation.connection_id}) || {};
});
</script>

<div class="sidebar-left" transition:fly="{transition}">
  <div class="sidebar-header">
    <h2>{$l('Connection')}</h2>
    <a href="#settings" class="btn-hallow is-active" on:click="{activeMenu.toggle}"><Icon name="times"/></a>
  </div>

  {#if !connection.url}
    <p>{$l('Connection not found.')}</p>
  {:else if connection.state == 'disconnected'}
    <p>{$l('Currently disconnected from %1.', connectionHost)}</p>
  {:else if connection.state == 'connected'}
    <p>{$l('Currently connected to %1.', connectionHost)}</p>
  {:else}
    <p>{$l('Currently connecting to %1.', connectionHost)}</p>
  {/if}

  <ConnectionForm id="{conversation.connection_id}"/>
</div>
