<script>
import {l} from '../js/i18n';
import FormActions from './form/FormActions.svelte';
import Link from './Link.svelte';
import PasswordField from './form/PasswordField.svelte';
import SidebarLoggedout from './SidebarLoggedout.svelte';
import TextField from './form/TextField.svelte';

function login(e) {
  e.preventDefault();
  console.log('TODO: Login');
}
</script>

<SidebarLoggedout/>

<main class="next-to-sidebar is-logged-out">
  <h1>{l('Log in')}</h1>
  <form class="login" method="post" on:submit="{login}">
    <TextField name="email" placeholder="{l('Ex: john@doe.com')}">
      <span slot="label">{l('E-mail')}</span>
    </TextField>
    <PasswordField name="password">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <FormActions>
      <button class="btn">{l('Log in')}</button>
    </FormActions>
  </form>
  <article>
    <p>{l('Welcome message. Vivamus congue mauris eu aliquet pharetra. Nulla sit amet dictum.')}</p>
  </article>
</main>