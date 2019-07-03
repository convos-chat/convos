<script>
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
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

async function setConnectionState(e) {
  const aEl = e.target.closest('a') || e.target;
  const clone = {connection_id: dialog.connection_id, wanted_state: aEl.href.replace(/.*#/, '')};
  await updateConnectionOp.perform(clone);
  user.ensureDialog(updateConnectionOp.res.body);
}

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

$: if (connection.url && formEl) {
  formEl.server.value = connection.url.host;
  formEl.nick.value = connection.url.searchParams.get('nick') || '';
  formEl.password.value = connection.url.password;
  formEl.username.value = connection.url.username;
  formEl.url.value = connection.url.toString();
}
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
    <button class="btn">{l('Update')}</button>
    <a href="#{isNotDisconnected ? 'disconnected' : 'connected'}" class="btn" on:click|preventDefault="{setConnectionState}">{l(isNotDisconnected ? 'Disconnect' : 'Connect')}</a>
    <a href="#delete" class="btn" on:click|preventDefault="{deleteConnection}">{l('Delete')}</a>
  </FormActions>
  <OperationStatus op={updateConnectionOp}/>
</form>
