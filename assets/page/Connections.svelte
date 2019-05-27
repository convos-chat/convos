<script>
import {getContext, tick} from 'svelte';
import {gotoUrl} from '../store/router';
import {l} from '../js/i18n';
import Checkbox from '../components/form/Checkbox.svelte';
import ConnURL from '../js/ConnURL';
import FormActions from '../components/form/FormActions.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import PromiseStatus from '../components/PromiseStatus.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import TextField from '../components/form/TextField.svelte';

const api = getContext('api');
let promise = false;
let showAdvancedSettings = false;
let url = '';

function onChange(e) {
  promise = false;
}

async function onSubmit(e) {
  const form = e.target;
  url = new ConnURL('irc://localhost:6667').fromForm(form).toString();
  await tick(); // Wait for url to update in form
  promise = api.execute('createConnection', form).then(res => { gotoUrl('/chat/' + res.connection_id) });
}
</script>

<SidebarChat/>

<main class="main-app-pane align-content-middle">
  <h1>{l('Add connection')}</h1>
  <form method="post" on:change={onChange} on:submit|preventDefault="{onSubmit}">
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
      <button class="btn">{l('Add connection')}</button>
    </FormActions>
    <PromiseStatus promise={promise}/>
  </form>
</main>
