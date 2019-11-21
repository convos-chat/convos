<script>
import Button from '../components/form/Button.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import TextField from '../components/form/TextField.svelte';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';
import {redirectAfterLogin, urlToForm} from '../store/router';

const emailFromParams = location.href.indexOf('email=') != -1;
const settings = getContext('settings');
const user = getContext('user');
const registerOp = user.api.operation('registerUser');

let formEl;

$: if ($registerOp.is('success')) {
  user.lastUrl(''); // Make sure the old value is forgotten
  redirectAfterLogin(user, registerOp);
}

onMount(() => {
  if (formEl) urlToForm(formEl);
});
</script>

<main class="main align-content-middle">
  {#if settings.status >= 400}
    <h1>{l('Invalid invite/recover URL')}</h1>
    <p>{l(settings.status == 410 ? 'The invite URL has expired.' : 'The invite token is invalid.')}</p>
    <p>{@html lmd('Please ask your [Convos admin](%1) for a new link.', settings.contact)}</p>
  {:else if emailFromParams || settings.open_to_public || settings.first_user}
    <h1>{l(settings.existing_user ? 'Recover account' : 'Create account')}</h1>
    <form method="post" on:submit|preventDefault="{e => registerOp.perform(e.target)}" bind:this="{formEl}">
      <input type="hidden" name="exp">
      <input type="hidden" name="token">

      <TextField name="email" placeholder="{l('Ex: john@doe.com')}" readonly="{emailFromParams}" bind:value="{user.formEmail}">
        <span slot="label">{l('E-mail')}</span>

        <p slot="help">
          {#if emailFromParams}
            {l('Your email is taken from the invite link.')}
          {:else}
            {l('Your email will be used if you forget your password.')}
          {/if}
        </p>
      </TextField>

      <PasswordField name="password">
        <span slot="label">{l('Password')}</span>
        <p slot="help">{l('Hint: Use a phrase from a book.')}</p>
      </PasswordField>

      <div class="form-actions">
        <Button icon="save" op="{registerOp}">{l(settings.existing_user ? 'Set new password' : 'Register')}</Button>
      </div>

      <p>{@html lmd('Go to [login](/login) if you already have an account.')}</p>

      <OperationStatus op="{registerOp}"/>
    </form>
  {:else}
    <h1>{l('Create account')}</h1>
    <p>{l('Convos is not open for public registration.')}</p>
    <p>{@html lmd('Please ask your [Convos admin](%1) for an invite link to register, or [login](/login) if you already have an account.', settings.contact)}</p>
  {/if}
</main>
