<script>
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarLoggedout from '../components/SidebarLoggedout.svelte';
import TextField from '../components/form/TextField.svelte';

const inviteCodeRequired = true;
const user = getContext('user');
const registerOp = user.api.operation('registerUser');

$: if ($registerOp.is('success')) {
  document.cookie = registerOp.res.headers['Set-Cookie'];
  registerOp.reset();
  user.load();
}
</script>

<SidebarLoggedout/>

<main class="main align-content-middle">
  <h1>{l('Create account')}</h1>
  <form method="post" on:submit|preventDefault="{e => registerOp.perform(e.target)}">
    <TextField name="email" placeholder="{l('Ex: john@doe.com')}">
      <span slot="label">{l('E-mail')}</span>
    </TextField>
    <PasswordField name="password">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
  {#if inviteCodeRequired}
    <TextField name="invite_code">
      <span slot="label">{l('Invite code')}</span>
    </TextField>
  {/if}
    <div class="form-actions">
      <button class="btn" op="{registerOp}">{l('Register')}</button>
    </div>
    <OperationStatus op="{registerOp}"/>
  </form>
</main>
