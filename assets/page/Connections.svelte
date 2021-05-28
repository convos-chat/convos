<script>
import ChatHeader from '../components/ChatHeader.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import OperationStatusRow from '../components/OperationStatusRow.svelte';
import {getContext, onMount} from 'svelte';
import {is} from '../js/util';
import {l} from '../store/I18N';

export const title = 'Connections';

const user = getContext('user');
const connectionProfiles = user.connectionProfiles;
const normalizeConnection = (connection) => connection.url.toFields({connection_id: connection.connection_id});

let connections = [];

$: if ($user.is('success') && !connections.length) connections = user.connections.toArray().map(normalizeConnection);
$: isAdmin = user.roles.has('admin');

onMount(() => connectionProfiles.load());
</script>

<ChatHeader>
  <h1>{$l('Connections')}</h1>
</ChatHeader>

<main class="main">
  <h2>{$l('Connections')}</h2>
  <table>
    <thead>
      <tr>
        <th>{$l('Host')}</th>
        <th>{$l('Secure')}</th>
        <th>{$l('Nick')}</th>
      </tr>
    </thead>
    <tbody>
      {#each connections as connection}
        <tr>
          <td><Link href="/settings/connection/{connection.connection_id}">{connection.host.replace(/:\d+$/, '')}</Link></td>
          <td>{is.true(connection.tls_verify) ? $l('Strict') : is.true(connection.tls) ? $l('Yes') : $l('No')}</td>
          <td>{connection.nick}</td>
        </tr>
      {/each}
    </tbody>
  </table>
  {#if isAdmin || !user.forced_connection}
    <div class="form-actions">
      <Link href="/settings/connection/add" class="btn"><Icon name="plus-circle"/> <span>{$l('Add')}</span></Link>
    </div>
  {/if}

  <h2>{$l('Connection profiles')}</h2>
  <p>{$l('Connection profiles are used to set up global values for every connection that connect to the same host.')}</p>
  <table>
    <thead>
      <tr>
        <th>{$l('Host')}</th>
        <th>{$l('Secure')}</th>
        <th>{$l('Default')}</th>
        <th>{$l('Forced')}</th>
      </tr>
    </thead>
    <tbody>
      <OperationStatusRow op="{connectionProfiles.op}"/>
      {#each $connectionProfiles.search() as profile}
        <tr>
          <td><Link href="/settings/connection-profile/{profile.id}">{profile.url.host.replace(/:\d+$/, '')}</Link></td>
          <td>{is.true(profile.tls_verify) ? $l('Strict') : is.true(profile.tls) ? $l('Yes') : $l('No')}</td>
          <td>{profile.is_default ? $l('Yes') : $l('No')}</td>
          <td>{profile.is_forced ? $l('Yes') : $l('No')}</td>
        </tr>
      {/each}
    </tbody>
  </table>
  {#if isAdmin}
    <div class="form-actions">
      <Link href="/settings/connection-profile/add" class="btn"><Icon name="plus-circle"/> <span>{$l('Add')}</span></Link>
    </div>
  {/if}
</main>
