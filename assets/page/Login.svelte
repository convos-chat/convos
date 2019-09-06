<script>
import {l} from '../js/i18n';
import {getContext} from 'svelte';
import FormActions from '../components/form/FormActions.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarLoggedout from '../components/SidebarLoggedout.svelte';
import TextField from '../components/form/TextField.svelte';

const user = getContext('user');
</script>

<SidebarLoggedout/>

<main class="main align-content-middle">
  <h1>{l('Log in')}</h1>
  <form method="post" on:submit|preventDefault="{e => user.login.perform(e.target)}">
    <TextField name="email" placeholder="{l('Ex: john@doe.com')}">
      <span slot="label">{l('E-mail')}</span>
    </TextField>
    <PasswordField name="password">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <FormActions>
      <button class="btn" op="{user.login}">{l('Log in')}</button>
    </FormActions>
    <OperationStatus op="{user.login}"/>
  </form>
  <article>
    <p>{l('Welcome message. Vivamus congue mauris eu aliquet pharetra. Nulla sit amet dictum.')}</p>
  </article>
</main>
