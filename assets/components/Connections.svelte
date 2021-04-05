<script>
import ConnectionForm from '../components/ConnectionForm.svelte';
import Icon from '../components/Icon.svelte';
import {is} from '../js/util';
import {l, lmd} from '../store/I18N';
import {getContext} from 'svelte';
import {route} from '../store/Route';

export let editConnection = null;

const user = getContext('user');

let showAdvancedSettings = false;
let connections = [];

$: if (user.is('success') && !connections.length) connections = user.connections.toArray().map(normalizeConnection);
$: isAdmin = user.roles.has('admin');
$: findConnection($route, connections);

function findConnection(route, connections) {
  const connection_id = route.hash.replace(/^connection-/, '');
  editConnection = connections.filter(c => c.connection_id == connection_id)[0] || null;
  if (route.hash == 'add-connection') editConnection = {};
}

function normalizeConnection(connection) {
  return connection.url.toFields({connection_id: connection.connection_id});
}
</script>

{#if editConnection}
  <ConnectionForm id="{editConnection && editConnection.connection_id}"/>
{:else}
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
          <td><a href="#connection-{connection.connection_id}">{connection.host.replace(/:\d+$/, '')}</a></td>
          <td>{is.true(connection.tls_verify) ? $l('Strict') : is.true(connection.tls) ? $l('Yes') : $l('No')}</td>
          <td>{connection.nick}</td>
        </tr>
      {/each}
    </tbody>
  </table>
  {#if isAdmin}
    <div class="form-actions">
      <a href="#add-connection" class="btn"><Icon name="plus-circle"/> <span>{$l('Add')}</span></a>
    </div>
  {/if}
{/if}
