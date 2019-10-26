<script>
import {getContext} from 'svelte';
import {l, lmd} from '../js/i18n';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarLoggedout from '../components/SidebarLoggedout.svelte';
import TextField from '../components/form/TextField.svelte';

const settings = getContext('settings');
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
    <p class="help">{l('Your email will be used if you forget your password.')}</p>

    <PasswordField name="password">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <p class="help">{l('Hint: Use a phrase from a book.')}</p>
  {#if settings.invite_code}
    <TextField name="invite_code">
      <span slot="label">{l('Invite code')}</span>
    </TextField>
    <p class="help">{@html lmd('Ask %1 for an invite code.', settings.contact)}</p>
  {/if}
    <div class="form-actions">
      <button class="btn" op="{registerOp}">{l('Register')}</button>
    </div>
    <OperationStatus op="{registerOp}"/>
  </form>
</main>
