<script>
import {l} from '../js/i18n';
import FormActions from '../components/form/FormActions.svelte';
import Link from '../components/Link.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarLoggedout from '../components/SidebarLoggedout.svelte';
import TextField from '../components/form/TextField.svelte';

function onSubmit(e) {
  promise = api.execute('loginUser', e.target).then((res) => {
    document.cookie = res.headers['Set-Cookie'];
    gotoUrl('/');
  });
}
</script>

<SidebarLoggedout/>

<main class="next-to-sidebar is-logged-out">
  <h1>{l('Log in')}</h1>
  <form class="login" method="post" on:submit|preventDefault="{onSubmit}">
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
