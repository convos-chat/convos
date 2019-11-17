<script>
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import TextField from '../components/form/TextField.svelte';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';
import {redirectAfterLogin} from '../store/router';

const emailFromParams = location.href.indexOf('email=') != -1;
const settings = getContext('settings');
const user = getContext('user');
const registerOp = user.api.operation('registerUser');

let formEl;

$: if ($registerOp.is('success')) redirectAfterLogin(user, registerOp);

onMount(() => {
  if (formEl) urlToForm(formEl);
});
</script>

<main class="main align-content-middle">
  {#if settings.status >= 400}
    <h1>{l('Invalid invite/recover URL')}</h1>
    <p>{l(settings.status == 410 ? 'The invite URL has expired.' : 'The invite token is invalid.')}</p>
    <p>{@html lmd('Please ask your [Convos admin](%1) for a new link.', settings.contact)}</p>
  {:else if emailFromParams || settings.openToPublic}
    <h1>{l(settings.existingUser ? 'Recover account' : 'Create account')}</h1>
    <form method="post" on:submit|preventDefault="{e => registerOp.perform(e.target)}" bind:this="{formEl}">
      <input type="hidden" name="exp">
      <input type="hidden" name="token">

      <TextField name="email" placeholder="{l('Ex: john@doe.com')}" readonly="{emailFromParams}">
        <span slot="label">{l('E-mail')}</span>
      </TextField>

      {#if !emailFromParams}
        <p class="help">{l('Your email will be used if you forget your password.')}</p>
      {/if}

      <PasswordField name="password">
        <span slot="label">{l('Password')}</span>
      </PasswordField>
      <p class="help">{l('Hint: Use a phrase from a book.')}</p>

      <div class="form-actions">
        <button class="btn" op="{registerOp}">{l(settings.existingUser ? 'Set new password' : 'Register')}</button>
      </div>
      <OperationStatus op="{registerOp}"/>
    </form>
  {:else}
    <h1>{l('Create account')}</h1>
    <p>{l('Convos is not open for public registration.')}</p>
    <p>{@html lmd('Please ask your [Convos admin](%1) for an invite link.', settings.contact)}</p>
  {/if}
</main>
