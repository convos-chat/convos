<script>
import {getContext, onMount, tick} from 'svelte';
import {gotoUrl} from '../store/router';
import {l} from '../js/i18n';
import Button from '../components/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import ConnURL from '../js/ConnURL';
import FormActions from '../components/form/FormActions.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SettingsHeader from '../components/SettingsHeader.svelte';
import TextField from '../components/form/TextField.svelte';

export let dialog = {};

const user = getContext('user');
const createConnectionOp = user.api.operation('createConnection');
const removeConnectionOp = user.api.operation('removeConnection');
const updateConnectionOp = user.api.operation('updateConnection');

let connection = {};
let formEl;
let showAdvancedSettings = false;
let useTls = false;
let verifyTls = false;
let wantToBeConnected = false;

$: if (formEl) formEl.wanted_state.value = wantToBeConnected ? 'connected' : 'disconnected';

function defaultsToForm() {
  formEl.nick.value = user.email.replace(/@.*/, '').replace(/\W/g, '_');
  useTls = true;
  wantToBeConnected = true;
}

function connectionToForm() {
  if (!connection.url) return; // Could not find connection
  formEl.server.value = connection.url.host;
  formEl.nick.value = connection.url.searchParams.get('nick') || '';
  formEl.password.value = connection.url.password;
  formEl.username.value = connection.url.username;
  formEl.url.value = connection.url.toString();
  useTls = connection.url.searchParams.get('tls') == '1' && true || false;
  verifyTls = connection.url.searchParams.get('tls_verify') == '1' && true || false;
  wantToBeConnected = connection.wanted_state == 'connected';
}

async function removeConnection(e) {
  await removeConnectionOp.perform(connection);
  user.removeDialog(connection);
  gotoUrl('/chat');
}

async function submitForm(e) {
  if (!formEl.server.value) return; // TODO: Inform that it is required

  formEl.url.value = new ConnURL('irc://localhost:6667').fromForm(e.target).toString();

  if (connection.connection_id) {
    await updateConnectionOp.perform(e.target);
    user.ensureDialog(updateConnectionOp.res.body);
    connectionToForm();
  }
  else {
    await createConnectionOp.perform(e.target);
    const conn = user.ensureDialog(createConnectionOp.res.body);
    gotoUrl('/chat/' + conn.path);
  }
}

onMount(async () => {
  await user.load();
  connection = user.findDialog({connection_id: dialog.connection_id}) || {};
  return connection.url ? connectionToForm() : defaultsToForm();
});
</script>

<form method="post" bind:this="{formEl}" on:submit|preventDefault="{submitForm}">
  {#if connection.connection_id}
    <input type="hidden" name="connection_id" value="{connection.connection_id}">
  {/if}
  <input type="hidden" name="url">
  <input type="hidden" name="wanted_state">

  <TextField name="server" placeholder="{l('Ex: chat.freenode.net:6697')}">
    <span slot="label">{l('Host and port')}</span>
  </TextField>
  <TextField name="nick" placeholder="{l('Ex: your-name')}">
    <span slot="label">{l('Nickname')}</span>
  </TextField>
  {#if connection.url}
    <Checkbox bind:checked="{wantToBeConnected}">
      <span slot="label">{l('Want to be connected')}</span>
    </Checkbox>
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
  <PasswordField name="password" hidden="{!showAdvancedSettings}">
    <span slot="label">{l('Password')}</span>
  </PasswordField>
  <FormActions>
    {#if connection.url}
      <Button icon="save">{l('Update')}</Button>
      <Button icon="trash" type="button" on:click|preventDefault="{removeConnection}">{l('Delete')}</Button>
    {:else}
      <Button icon="save">{l('Create')}</Button>
    {/if}
  </FormActions>
  <OperationStatus op={updateConnectionOp}/>
</form>
