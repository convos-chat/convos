<script>
import Button from '../components/form/Button.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import Scrollspy from '../js/Scrollspy';
import TextField from '../components/form/TextField.svelte';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';
import {q} from '../js/util';
import {route} from '../store/Route';

const emailFromParams = location.href.indexOf('email=') != -1;
const user = getContext('user');
const scrollspy = new Scrollspy();
const loginOp = user.api.operation('loginUser');
const registerOp = user.api.operation('registerUser');

let formEl;

$: redirect($user);
$: route.update({title: $route.path.match(/register/) ? l('Register') : l('Login')});
$: scrollspy.scrollTo($route.hash ? '#' + $route.hash : 0);
$: if ($loginOp.is('success')) redirectAfterLogin(loginOp);
$: if ($registerOp.is('success')) registered();

function redirect(user) {
  const dialog = user.dialogs()[0];
  const url = route.lastUrl ? route.lastUrl : dialog ? dialog.path : '/settings/connection';
  if (user.is('loading') || !user.is('authenticated')) return;
  route.go(url);
}

onMount(() => {
  if (formEl) route.urlToForm(formEl);
});

async function redirectAfterLogin(op) {
  op.reset();
  await user.load();
  return user.is('authenticated') ? route.go('/') : location.reload();
}

function registered() {
  route.update({lastUrl: ''}); // Make sure the old value is forgotten
  redirectAfterLogin(registerOp);
}
</script>

<section id="signup">
  {#if process.env.status >= 400}
    <h2>{l('Invalid invite/recover URL')}</h2>
    <p>{l(process.env.status == 410 ? 'The link has expired.' : 'The link is invalid.')}</p>
    <p>{l('Please ask your Convos admin for a new link.')}</p>
    <p>
      <a class="btn" href="{process.env.contact}">{l('Contact admin')}</a>
    </p>
  {:else if emailFromParams || process.env.open_to_public || $user.isFirst}
    <form method="post" on:submit|preventDefault="{e => registerOp.perform(e.target)}" bind:this="{formEl}">
      <h2>{l(process.env.existing_user ? 'Recover account' : 'Sign up')}</h2>
      {#if $user.isFirst}
        <p>{l('As you are the first user, you do not need any invitation link. Just fill in the form below, hit "Sign up" to start chatting.')}</p>
      {/if}
      <input type="hidden" name="exp">
      <input type="hidden" name="token">

      <TextField type="email" name="email" placeholder="{l('Ex: john@doe.com')}" readonly="{emailFromParams}" bind:value="{user.formEmail}">
        <span slot="label">{l('E-mail')}</span>
        <p class="help" slot="help">
          {#if emailFromParams}
            {l('Your email is from the invite link.')}
          {:else}
            {l('Your email will be used if you forget your password.')}
          {/if}
        </p>
      </TextField>

      <TextField type="password" name="password">
        <span slot="label">{l('Password')}</span>
        <p class="help" slot="help">{l('Hint: Use a phrase from a book.')}</p>
      </TextField>

      <div class="form-actions">
        <Button icon="save" op="{registerOp}"><span>{l(process.env.existing_user ? 'Set new password' : 'Sign up')}</span></Button>
      </div>

      <OperationStatus op="{registerOp}"/>
    </form>
  {:else}
    <h2>{l('Sign up')}</h2>
    <p>{l('Convos is not open for public registration.')}</p>
    <p on:click="{scrollspy.scrollTo}">{l('Please ask your Convos admin for an invite link to sign up, or sign in if you already have an account.')}</p>
    <div class="form-actions">
      <a class="btn" href="{process.env.contact}"><Icon name="paper-plane"/> {l('Contact admin')}</a>
    </div>
  {/if}
</section>

{#if !$user.isFirst}
  <section id="signin">
    <form method="post" on:submit|preventDefault="{e => loginOp.perform(e.target)}">
      <h2>{l('Sign in')}</h2>
      <TextField type="email" name="email" placeholder="{l('Ex: john@doe.com')}" bind:value="{user.formEmail}">
        <span slot="label">{l('E-mail')}</span>
      </TextField>

      <TextField type="password" name="password" autocomplete="current-password">
        <span slot="label">{l('Password')}</span>
        <p class="help" slot="help">{@html lmd('Contact your [Convos admin](%1) if you have forgotten your password.', process.env.contact)}</p>
      </TextField>

      <div class="form-actions">
        <Button icon="sign-in-alt" op="{loginOp}"><span>{l('Sign in')}</span></Button>
      </div>

      <OperationStatus op="{loginOp}"/>
    </form>
  </section>
{/if}
