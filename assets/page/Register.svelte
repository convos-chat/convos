<script>
import {getContext} from 'svelte';
import {gotoUrl} from '../store/router';
import {l} from '../js/i18n';
import FormActions from '../components/form/FormActions.svelte';
import Link from '../components/Link.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import PromiseStatus from '../components/PromiseStatus.svelte';
import SidebarLoggedout from '../components/SidebarLoggedout.svelte';
import TextField from '../components/form/TextField.svelte';

const inviteCodeRequired = true;
const api = getContext('api');

let promise = false;
function onChange(e) {
  promise = false;
}

function onSubmit(e) {
  promise = api.execute('registerUser', e.target).then((res) => {
    document.cookie = res.headers['Set-Cookie'];
    gotoUrl('/');
  });
}
</script>

<SidebarLoggedout/>

<main class="next-to-sidebar is-logged-out">
  <h1>{l('Create account')}</h1>
  <form class="login" method="post" on:change={onChange} on:submit|preventDefault="{onSubmit}">
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
    <PromiseStatus promise={promise}/>
  </form>
  <article>
    <p>{l('By creating an account, you agree to the use of cookies.')}</p>
  </article>
</main>