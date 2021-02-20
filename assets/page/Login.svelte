<script>
import Button from '../components/form/Button.svelte';
import Icon from '../components/Icon.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import TextField from '../components/form/TextField.svelte';
import {getContext, onMount} from 'svelte';
import {i18n, l, lmd} from '../store/I18N';
import {route} from '../store/Route';
import {settings} from '../js/util';

export let title = 'Login';

const api = getContext('api');
const user = getContext('user');

const emailFromParams = location.href.indexOf('email=') != -1;
const loginOp = api('loginUser');
const registerOp = api('registerUser');

let formEl;

$: redirect($user);
$: if ($loginOp.is('success')) redirectAfterLogin(loginOp);
$: if ($registerOp.is('success')) registered();
$: title = $route.path.match(/register/) ? 'Register' : 'Login';

function redirect(user) {
  const conversation = user.conversations()[0];
  const url = route.lastUrl ? route.lastUrl : conversation ? conversation.path : '/settings/connection';
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

<main id="sigup" class="cms-main">
  {#if settings('status') >= 400}
    <h2>{$l('Invalid invite/recover URL')}</h2>
    <p>{$l(settings('status') == 410 ? 'The link has expired.' : 'The link is invalid.')}</p>
    <p>{$l('Please ask your Convos admin for a new link.')}</p>
    <p>
      <a class="btn" href="{settings('contact')}">{$l('Contact admin')}</a>
    </p>
  {:else if emailFromParams || settings('open_to_public') || settings('first_user')}
    <form method="post" on:submit|preventDefault="{e => registerOp.perform(e.target)}" bind:this="{formEl}">
      <h2>{$l(settings('existing_user') ? 'Recover account' : 'Sign up')}</h2>
      {#if settings('first_user')}
        <p>{$l('As you are the first user, you do not need any invitation link. Just fill in the form below, hit "Sign up" to start chatting.')}</p>
      {/if}
      <input type="hidden" name="exp">
      <input type="hidden" name="token">

      <TextField type="email" name="email" placeholder="{$l('Ex: john@doe.com')}" readonly="{emailFromParams}" bind:value="{user.formEmail}">
        <span slot="label">{$l('Email')}</span>
        <p class="help" slot="help">
          {#if emailFromParams}
            {$l('Your email is from the invite link.')}
          {:else}
            {$l('Your email will be used if you forget your password.')}
          {/if}
        </p>
      </TextField>

      <TextField type="password" name="password">
        <span slot="label">{$l('Password')}</span>
        <p class="help" slot="help">{$l('Hint: Use a phrase from a book.')}</p>
      </TextField>

      <div class="form-actions">
        <Button icon="save" op="{registerOp}"><span>{$l(settings('existing_user') ? 'Set new password' : 'Sign up')}</span></Button>
      </div>

      <OperationStatus op="{registerOp}"/>
    </form>
  {:else}
    <h2>{$l('Sign up')}</h2>
    <p>{$l('Please ask your Convos admin for an invite link to sign up, or sign in if you already have an account.')}</p>
    <div class="form-actions">
      <a class="btn" href="{settings('contact')}"><Icon name="paper-plane"/> {$l('Contact admin')}</a>
    </div>
  {/if}
</main>

{#if !settings('first_user')}
  <main id="signin" class="cms-main">
    <form method="post" on:submit|preventDefault="{e => loginOp.perform(e.target)}">
      <h2>{$l('Sign in')}</h2>
      <TextField type="email" name="email" placeholder="{$l('Ex: john@doe.com')}" bind:value="{user.formEmail}">
        <span slot="label">{$l('Email')}</span>
      </TextField>

      <TextField type="password" name="password" autocomplete="current-password">
        <span slot="label">{$l('Password')}</span>
        <p class="help" slot="help">{@html $lmd('Contact your [Convos admin](%1) if you have forgotten your password.', settings('contact'))}</p>
      </TextField>

      <div class="form-actions">
        <Button icon="sign-in-alt" op="{loginOp}"><span>{$l('Sign in')}</span></Button>
      </div>

      <OperationStatus op="{loginOp}"/>
    </form>
  </main>
{/if}

<div class="footer--wrapper is-small">
  <footer class="footer language-selector">
    <Icon name="globe"/>
    {#each $i18n.languageOptions as lang}
      <a href="#{lang[0]}" on:click="{() => $i18n.load(lang[0])}">{lang[1]}</a>
    {/each}
  </footer>
</div>
