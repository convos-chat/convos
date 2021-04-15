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

let password = '';
let formEl;

$: redirect($user);
$: if ($loginOp.is('success')) redirectAfterLogin(loginOp);
$: if ($registerOp.is('success')) registered();
$: show = calculateShow($route);
$: title = $route.path.match(/register/) ? 'Register' : 'Login';

function calculateShow() {
  if ($route.hash && ['signin', 'signup'].indexOf($route.hash) != -1) return $route.hash;
  if (settings('first_user') || settings('open_to_public')) return 'signup';
  return 'signin';
}

function redirect(user) {
  const conversation = user.conversations()[0];
  const url = route.lastUrl ? route.lastUrl : conversation ? conversation.path : '/settings/connections';
  if (user.is('loading') || !user.is('authenticated')) return;
  route.go(url);
}

onMount(() => {
  if (formEl) route.urlToForm(formEl);
  if (formEl && !('ontouchstart' in window)) formEl.querySelector('input').focus();
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

<main class="cms-main">
  <div id="signup" class:hidden="{show != 'signup'}">
    {#if settings('status') >= 400}
      <h2>{$l('Invalid invite/recover URL')}</h2>
      <p>{$l(settings('status') == 410 ? 'The link has expired.' : 'The link is invalid.')}</p>
      <p>{$l('Please ask your Convos admin for a new link.')}</p>
      <p>
        <a class="btn" href="{settings('contact')}">{$l('Contact admin')}</a>
        <a href="#signin" replace>{$l('Sign in')}</a>
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

        <TextField type="password" name="password" bind:value="{password}">
          <span slot="label">{$l('Password')}</span>
          <p class="help" slot="help">{$l('Hint: Use a phrase from a book.')}</p>
        </TextField>

        <div class="form-actions">
          <Button icon="save" op="{registerOp}"><span>{$l(settings('existing_user') ? 'Set new password' : 'Sign up')}</span></Button>
          <a href="#signin" replace>{$l('Sign in')}</a>
        </div>

        <OperationStatus op="{registerOp}" success="Loading Convos..."/>
      </form>
    {:else}
      <h2>{$l('Sign up')}</h2>
      <p>{$l('Please ask your Convos admin for an invite link to sign up, or sign in if you already have an account.')}</p>
      <div class="form-actions">
        <a class="btn" href="{settings('contact')}"><Icon name="paper-plane"/> {$l('Contact admin')}</a>
        <a href="#signin" replace>{$l('Sign in')}</a>
      </div>
    {/if}
  </div>

  {#if !settings('first_user')}
    <div id="signin" class:hidden="{show != 'signin'}">
      <form method="post" on:submit|preventDefault="{e => loginOp.perform(e.target)}" bind:this="{formEl}">
        <h2>{$l('Sign in')}</h2>
        <TextField type="email" name="email" placeholder="{$l('Ex: john@doe.com')}" bind:value="{user.formEmail}">
          <span slot="label">{$l('Email')}</span>
        </TextField>

        <TextField type="password" name="password" autocomplete="current-password" bind:value="{password}">
          <span slot="label">{$l('Password')}</span>
          <p class="help" slot="help">{@html $lmd('Contact your [Convos admin](%1) if you have forgotten your password.', settings('contact'))}</p>
        </TextField>

        <div class="form-actions">
          <Button icon="sign-in-alt" op="{loginOp}"><span>{$l('Sign in')}</span></Button>
          <a href="#signup">{$l('Sign up')}</a>
        </div>

        <OperationStatus op="{loginOp}" success="Loading Convos..."/>
      </form>
    </div>
  {/if}
</main>

<div class="footer--wrapper is-small">
  <footer class="footer language-selector">
    <Icon name="globe"/>
    {#each $i18n.languageOptions as lang}
      <a href="#{lang[0]}" on:click="{() => $i18n.load(lang[0])}">{lang[1]}</a>
    {/each}
  </footer>
</div>
