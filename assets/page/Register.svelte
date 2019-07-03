<script>
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import FormActions from '../components/form/FormActions.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarLoggedout from '../components/SidebarLoggedout.svelte';
import TextField from '../components/form/TextField.svelte';

const inviteCodeRequired = true;
const user = getContext('user');
</script>

<SidebarLoggedout/>

<main class="main align-content-middle">
  <h1>{l('Create account')}</h1>
  <form method="post" on:submit|preventDefault="{e => user.register.perform(e.target)}">
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
    <FormActions>
      <button class="btn">{l('Register')}</button>
    </FormActions>
    <OperationStatus op={user.register}/>
  </form>
  <article>
    <p>{l('By creating an account, you agree to the use of cookies.')}</p>
  </article>
</main>
