<script>
import {connections, ensureConnection} from '../store/user';
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import Checkbox from '../components/form/Checkbox.svelte';
import ConnURL from '../js/ConnURL';
import FormActions from '../components/form/FormActions.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import PromiseStatus from '../components/PromiseStatus.svelte';
import StateIcon from '../components/StateIcon.svelte';
import TextField from '../components/form/TextField.svelte';

export let connectionId;

const api = getContext('api');
let formEl;
let promise = false;
let showAdvancedSettings = false;
let url = '';

function changeConnectionState(e) {
  const clone = {...connection, wanted_state: isDisconnected ? 'connected' : 'disconnected'};
  promise = api.execute('updateConnection', clone).then(ensureConnection);
}

function deleteConnection(e) {
  alert('TODO');
}

function onChange(e) {
  promise = false;
}

async function onSubmit(e) {
  url = new ConnURL('irc://localhost:6667').fromForm(e.target).toString();
  await tick(); // Wait for url to update in form
  promise = api.execute('updateConnection', e.target).then(ensureConnection);
}

$: connection = $connections.filter(c => c.connection_id == connectionId)[0] || {};
$: isDisconnected = connection.state == 'disconnected';

$: if (connection.url && formEl) {
  formEl.server.value = connection.url.host;
  formEl.nick.value = connection.url.searchParams.get('nick') || '';
  formEl.password.value = connection.url.password;
  formEl.username.value = connection.url.username;
  formEl.url.value = connection.url.toString();
}
</script>

<div class="settings-pane">
  <h2>{l('Connection settings')}</h2>
  <form method="post" bind:this="{formEl}" on:change={onChange} on:submit|preventDefault="{onSubmit}">
    <input type="hidden" name="connection_id" value="{connectionId}">
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
      <button class="btn">{l('Update connection')}</button>
      <a href="#{isDisconnected ? 'connect' : 'disconnect'}" class="btn" on:click|preventDefault="{changeConnectionState}">{l(isDisconnected ? 'Connect' : 'Disconnect')}</a>
      <a href="#delete" class="btn" on:click|preventDefault="{deleteConnection}">{l('Delete')}</a>
      <StateIcon obj="{connection}"/>
    </FormActions>
    <PromiseStatus promise={promise}/>
  </form>
</div>