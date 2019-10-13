<script>
import {l} from '../js/i18n';
import {getContext} from 'svelte';
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
  <form method="post" on:submit|preventDefault="{e => user.loginOp.perform(e.target)}">
    <TextField name="email" placeholder="{l('Ex: john@doe.com')}">
      <span slot="label">{l('E-mail')}</span>
    </TextField>
    <PasswordField name="password">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <div class="form-actions">
      <button class="btn" op="{user.loginOp}">{l('Log in')}</button>
    </div>
    <OperationStatus op="{user.loginOp}"/>
  </form>
  <article>
    <p>{l('Convos is the simplest way to use IRC and it keeps you always online.')}</p>
  </article>
</main>
