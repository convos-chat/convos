<script>
import {getContext, tick} from 'svelte';
import {gotoUrl} from '../store/router';
import {l} from '../js/i18n';
import Checkbox from '../components/form/Checkbox.svelte';
import ConnURL from '../js/ConnURL';
import FormActions from '../components/form/FormActions.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import TextField from '../components/form/TextField.svelte';

const user = getContext('user');
const createConnectionOp = user.api.operation('createConnection');

let showAdvancedSettings = false;
let url = '';

async function createConnectionFromForm(e) {
  url = new ConnURL('irc://localhost:6667').fromForm(e.target).toString();
  await tick(); // Wait for url to update in form
  const conn = await createConnectionOp.perform(e.target);
  user.ensureDialog(conn);
  gotoUrl('/chat/' + conn.path);
}
</script>

<SidebarChat/>

<main class="main align-content-middle">
  <h1>{l('Add connection')}</h1>

  <form method="post" on:submit|preventDefault="{createConnectionFromForm}">
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
    <TextField name="username" hidden="{!showAdvancedSettings}">
      <span slot="label">{l('Username')}</span>
    </TextField>
    <PasswordField name="password" hidden="{!showAdvancedSettings}">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <FormActions>
      <button class="btn">{l('Add connection')}</button>
    </FormActions>
    <OperationStatus op={createConnectionOp}/>
  </form>
</main>
