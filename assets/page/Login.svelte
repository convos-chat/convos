<script>
import {l} from '../js/i18n';
import {getContext} from 'svelte';
import {gotoUrl} from '../store/router';
import FormActions from '../components/form/FormActions.svelte';
import Link from '../components/Link.svelte';
import PromiseStatus from '../components/PromiseStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarLoggedout from '../components/SidebarLoggedout.svelte';
import TextField from '../components/form/TextField.svelte';

const api = getContext('api');

let promise = false;
function onSubmit(e) {
  promise = api.execute('loginUser', e.target).then((res) => {
    document.cookie = res.headers['Set-Cookie'];
    gotoUrl('/chat');
  });
}
</script>

<SidebarLoggedout/>

<main class="main-app-pane align-content-middle">
  <h1>{l('Log in')}</h1>
  <form method="post" on:submit|preventDefault="{onSubmit}">
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
