<script>
import {getContext, onMount} from 'svelte';
import {l} from '../js/i18n';
import ConnectionForm from '../components/ConnectionForm.svelte';
import SettingsHeader from '../components/SettingsHeader.svelte';

export let dialog = {};

const user = getContext('user');

let connection = {};

$: connectionHost = connection.url && connection.url.host;

onMount(async () => {
  await user.load();
  connection = user.findDialog({connection_id: dialog.connection_id}) || {};
});
</script>

<div class="sidebar-wrapper is-visible">
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
