<script>
import {getContext, onMount, tick} from 'svelte';
import {l} from '../js/i18n';
import Button from '../components/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import ConnURL from '../js/ConnURL';
import FormActions from '../components/form/FormActions.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import TextField from '../components/form/TextField.svelte';

export let dialog = {};

const user = getContext('user');
const updateConnectionOp = user.api.operation('updateConnection');

let formEl;
let showAdvancedSettings = false;
let url = '';
let useTls = false;
let verifyTls = false;
let wantToBeConnected = false;

async function deleteConnection(e) {
  alert('TODO');
}

async function updateConnectionFromForm(e) {
  url = new ConnURL('irc://localhost:6667').fromForm(e.target).toString();
  await tick(); // Wait for url to update in form
  await updateConnectionOp.perform(e.target);
  user.ensureDialog(updateConnectionOp.res.body);
}

$: connection = $user.findDialog({connection_id: dialog.connection_id}) || {};
$: isNotDisconnected = connection.state != 'disconnected';

onMount(async () => {
  if (!formEl) await tick();
  formEl.server.value = connection.url.host;
  formEl.nick.value = connection.url.searchParams.get('nick') || '';
  formEl.password.value = connection.url.password;
  formEl.username.value = connection.url.username;
  formEl.url.value = connection.url.toString();
  useTls = connection.url.searchParams.get('tls') && true || false;
  verifyTls = connection.url.searchParams.get('tls_verify') && true || false;
  wantToBeConnected = connection.wanted_state == 'connected';
  console.log('A', useTls);
});
</script>

<form method="post" bind:this="{formEl}" on:submit|preventDefault="{updateConnectionFromForm}">
  <input type="hidden" name="connection_id" value="{connection.connection_id}">
  <input type="hidden" name="url" value="{url}">
  <TextField name="server" placeholder="{l('Ex: chat.freenode.net:6697')}">
    <span slot="label">{l('Server and port')}</span>
  </TextField>
  <TextField name="nick" placeholder="{l('Ex: your-name')}">
    <span slot="label">{l('Nickname')}</span>
  </TextField>
  <Checkbox bind:checked="{wantToBeConnected}">
    <span slot="label">{l('Want to be connected')} ({l('Currently %1', connection.state || 'disconnected')})</span>
  </Checkbox>
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
  <TextField name="username" className="{showAdvancedSettings ? '' : 'hide'}">
    <span slot="label">{l('Username')}</span>
  </TextField>
  <PasswordField name="password" className="{showAdvancedSettings ? '' : 'hide'}">
    <span slot="label">{l('Password')}</span>
  </PasswordField>
  <FormActions>
    <Button icon="save">{l('Update')}</Button>
    <Button icon="trash" on:click|preventDefault="{deleteConnection}">{l('Delete')}</Button>
  </FormActions>
  <OperationStatus op={updateConnectionOp}/>
</form>
