<script>
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import ConnectionURL from '../js/ConnectionURL';
import OperationStatus from '../components/OperationStatus.svelte';
import SelectField from '../components/form/SelectField.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {getContext, onMount} from 'svelte';
import {route} from '../store/Route';
import {viewport} from '../store/Viewport';

export let conversation = {};

const api = getContext('api');
const user = getContext('user');
const saslMechanisms = [['none', 'None'], ['plain', 'Plain'], ['external', 'External']];

const createConnectionOp = api('createConnection');
const removeConnectionOp = api('removeConnection');
const updateConnectionOp = api('updateConnection');

[createConnectionOp, updateConnectionOp].forEach(op => {
  op.on('start', req => {
    req.body.on_connect_commands = req.body.on_connect_commands.split('\n').map(str => str.trim());
  });
});

let connection = {};
let formEl;
let saslMechanism = 'none';
let showAdvancedSettings = false;
let useTls = false;
let verifyTls = false;
let wantToBeConnected = false;


$: l = $viewport.l;
$: if (formEl) formEl.wanted_state.value = wantToBeConnected ? 'connected' : 'disconnected';

onMount(async () => {
  if (!formEl) return; // if unMounted while loading user data
  connection = user.findConversation({connection_id: conversation.connection_id}) || {};
  return connection.url ? connectionToForm() : defaultsToForm();
});

function defaultsToForm() {
  if (user.forced_connection) formEl.server.value = user.default_connection;
  formEl.nick.value = user.email.replace(/@.*/, '').replace(/\W/g, '_');
  saslMechanism = 'none';
  useTls = true;
  wantToBeConnected = true;

  if (!route.query.uri) return route.urlToForm(formEl);

  const connURL = new ConnectionURL(route.query.uri);
  const connParams = connURL.searchParams;

  if (connURL.host) formEl.server.value = connURL.host;
  if (connURL.password) formEl.password.value = connURL.password;
  if (connURL.username) formEl.username.value = connURL.username;
  if (connParams.get('nick')) formEl.nick.value = connParams.get('nick');
  if (connParams.get('realname')) formEl.realname.value = connParams.get('realname');
  if (connURL.pathname && formEl.conversation) formEl.conversation.value = decodeURIComponent(connURL.pathname.split('/').filter(p => p.length)[0] || '');
  if (connParams.get('sasl')) saslMechanism = connParams.get('sasl');
  if (Number(connParams.get('tls') || 0)) useTls = true;
  if (Number(connParams.get('tls_verify') || 0)) verifyTls = true;
}

function connectionToForm() {
  if (!connection.url) return; // Could not find connection
  formEl.server.value = connection.url.host;
  formEl.nick.value = connection.url.searchParams.get('nick') || '';
  formEl.realname.value = connection.url.searchParams.get('realname') || '';
  formEl.on_connect_commands.value = connection.on_connect_commands.join('\n');
  formEl.password.value = connection.url.password;
  formEl.username.value = connection.url.username;
  formEl.url.value = connection.url.toString();
  saslMechanism = connection.url.searchParams.get('sasl') || 'none';
  useTls = connection.url.searchParams.get('tls') == '1' && true || false;
  verifyTls = connection.url.searchParams.get('tls_verify') == '1' && true || false;
  wantToBeConnected = connection.wanted_state == 'connected';
}

async function removeConnection(e) {
  await removeConnectionOp.perform(connection);
  user.removeConversation(connection);
  route.go('/settings/connection');
}

async function submitForm(e) {
  if (!formEl.server.value) return; // TODO: Inform that it is required

  formEl.url.value = new ConnectionURL('irc://localhost:6667').fromForm(e.target).toString();

  if (connection.connection_id) {
    await updateConnectionOp.perform(e.target);
    connection = user.ensureConversation(updateConnectionOp.res.body);
    connectionToForm();
  }
  else {
    await createConnectionOp.perform(e.target);
    const conn = user.ensureConversation(createConnectionOp.res.body);
    route.go(conn.path);
  }
}
</script>

<form method="post" bind:this="{formEl}" on:submit|preventDefault="{submitForm}">
  {#if connection.connection_id}
    <input type="hidden" name="connection_id" value="{connection.connection_id}">
  {/if}
  <input type="hidden" name="url">
  <input type="hidden" name="wanted_state">

  <TextField name="server" placeholder="{l('Ex: chat.freenode.net:6697')}" readonly="{user.forced_connection}">
    <span slot="label">{l('Host and port')}</span>
    <p class="help" slot="help">
      {@html l.md(user.forced_connection ? 'You cannot create custom connections.' : 'Example: %1', 'chat.freenode.net:6697')}
    </p>
  </TextField>

  <TextField name="nick" placeholder="{l('Ex: superman')}">
    <span slot="label">{l('Nickname')}</span>
  </TextField>

  <TextField name="realname" placeholder="{l('Ex: Clark Kent')}">
    <span slot="label">{l('Your name')}</span>
    <p class="help" slot="help">Visible in WHOIS response</p>
  </TextField>

  {#if connection.url}
    <Checkbox bind:checked="{wantToBeConnected}">
      <span slot="label">{l('Want to be connected')}</span>
    </Checkbox>
  {:else}
    <TextField name="conversation_id" placeholder="{l('Ex: #convos')}">
      <span slot="label">{l('Conversation name')}</span>
    </TextField>
  {/if}

  <Checkbox name="tls" bind:checked="{useTls}">
    <span slot="label">{l('Secure connection (TLS)')}</span>
  </Checkbox>
  {#if useTls}
    <Checkbox name="tls_verify" bind:checked="{verifyTls}">
      <span slot="label">{l('Verify certificate (TLS)')}</span>
    </Checkbox>
  {/if}
  <Checkbox bind:checked="{showAdvancedSettings}">
    <span slot="label">{l('Show advanced settings')}</span>
  </Checkbox>
  <TextField name="username" hidden="{!showAdvancedSettings}">
    <span slot="label">{l('Username')}</span>
  </TextField>
  <TextField type="password" name="password" hidden="{!showAdvancedSettings}">
    <span slot="label">{l('Password')}</span>
  </TextField>
  <SelectField name="sasl" options="{saslMechanisms}" bind:value="{saslMechanism}" hidden="{!showAdvancedSettings}">
    <span slot="label">{l('SASL authentication mechanism')}</span>
  </SelectField>
  <TextArea name="on_connect_commands" placeholder="{l('Put each command on a new line.')}" hidden="{!showAdvancedSettings}">
    <span slot="label">{l('On-connect commands')}</span>
  </TextArea>
  <div class="form-actions">
    {#if connection.url}
      <Button icon="save" op="{updateConnectionOp}"><span>{l('Update')}</span></Button>
      <Button icon="trash" type="button" op="{removeConnectionOp}" on:click="{removeConnection}"><span>{l('Delete')}</span></Button>
    {:else}
      <Button icon="save" op="{createConnectionOp}"><span>{l('Create')}</span></Button>
    {/if}
  </div>
  <OperationStatus op="{createConnectionOp}"/>
  <OperationStatus op="{removeConnectionOp}"/>
  <OperationStatus op="{updateConnectionOp}"/>
</form>
