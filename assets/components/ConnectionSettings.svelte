<script>
import ConnectionForm from '../components/ConnectionForm.svelte';
import SettingsHeader from '../components/SettingsHeader.svelte';
import {container} from '../store/router';
import {fly} from 'svelte/transition';
import {getContext, onMount} from 'svelte';
import {l} from '../js/i18n';

export let dialog = {};

const user = getContext('user');

let connection = {};

$: connectionHost = connection.url && connection.url.host;
$: flyTransitionParameters = {duration: $container.small ? 250 : 0, x: $container.width};

onMount(async () => {
  await user.load();
  connection = user.findDialog({connection_id: dialog.connection_id}) || {};
});
</script>

<div class="sidebar-wrapper is-visible" transition:fly="{flyTransitionParameters}">
  <SettingsHeader {dialog}/>

  {#if !connection.url}
    <p>{l('Connection not found.')}</p>
  {:else if connection.state == 'disconnected'}
    <p>{l('Currently disconnected from %1.', connectionHost)}</p>
  {:else if connection.state == 'connected'}
    <p>{l('Currently connected to %1.', connectionHost)}</p>
  {:else}
    <p>{l('Currently connecting to %1.', connectionHost)}</p>
  {/if}

  <ConnectionForm {dialog}/>
</div>
