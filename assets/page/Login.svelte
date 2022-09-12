<script>
import Button from '../components/form/Button.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import TextField from '../components/form/TextField.svelte';
import {convosApi} from '../js/Api';
import {getContext} from 'svelte';
import {i18n, l, lmd} from '../store/I18N';
import {q, settings} from '../js/util';
import {route} from '../store/Route';

export let title = 'Sign in';

const user = getContext('user');

const loginOp = convosApi.op('loginUser');
const registerOp = convosApi.op('registerUser');

let form = {};

$: redirect($user);
$: mode = renderForm($route);

function redirect(user) {
  if (user.is('loading') || !user.email) return;
  const conversation = user.conversations()[0];
  const url = user.lastUrl ? user.lastUrl : conversation ? conversation.path : '/settings/connections';
  route.go(url, {replace: true});
}

function renderForm($route) {
  const register = $route.path.indexOf('register') != -1;
  const mode
    = !form.mode && settings('status') >= 400            ? 'invalid_invitation' // Only show error the first time
    : $route.param('email') && settings('existing_user') ? 'recover'
    : $route.param('email')                              ? 'invitation'
    : settings('first_user')                             ? 'register'
    : register && settings('open_to_public')             ? 'register'
    : register                                           ? 'invalid'
    :                                                      'login';

  form = {
    email: $route.param('email') || form.email || '',
    exp: $route.param('exp') || '',
    mode: mode,
    password: '',
    token: $route.param('token') || '',
  };

  title = mode == 'login' ? 'Sign in' : 'Sign up';

  if (!('ontouchstart' in window)) {
    setTimeout(() => q(document, '.text-field input').reverse().map(el => el.readOnly || el.focus()), 1);
  }

  return mode;
}

async function submitForm(e) {
  const op = mode == 'login' ? loginOp : registerOp;

  // Make sure we get the auto-filled value, in case on:input="..." is not enough
  const formEl = e.target.closest('form');
  form.email = formEl.email.value;
  form.password = formEl.password.value;

  await op.perform(form);
  if (mode != 'login') route.update({lastUrl: ''}); // Make sure the old value is forgotten
  if (!op.error()) await user.load(); // Causes redirect() to be called
}
</script>

<main class="cms-main">
  <form method="post" on:submit|preventDefault="{submitForm}">
    <input type="hidden" name="mode" bind:value="{form.mode}"/>
    {#if mode == 'invalid_invitation'}
      <h2>{$l('Invalid invite/recover URL')}</h2>
      <p>{$l(settings('status') == 410 ? 'The link has expired.' : 'The link is invalid.')}</p>
      <p>{$l('Please ask your Convos admin for a new link.')}</p>
      <p>
        <a class="btn" href="{settings('contact')}">{$l('Contact admin')}</a>
        <Link href="/login">{$l('Sign in')}</Link>
      </p>
    {:else if ['recover', 'invitation', 'register'].indexOf(mode) != -1}
      <h2>{mode == 'recover' ? $l('Recover account') : $l('Sign up')}</h2>
      {#if settings('first_user')}
        <p>{$l('As you are the first user, you do not need any invitation link. Just fill in the form below, hit "Sign up" to start chatting.')}</p>
      {/if}

      <input type="hidden" name="exp" bind:value="{form.exp}"/>
      <input type="hidden" name="token" bind:value="{form.token}"/>
      <TextField type="email" name="email" bind:value="{form.email}" placeholder="{$l('Ex: john@doe.com')}" readonly="{mode != 'register'}">
        <span slot="label">{$l('Email')}</span>
        <p class="help" slot="help">{mode == 'invitation' ? $l('Your email is from the invite link.') : $l('Your email will be used if you forget your password.')}</p>
      </TextField>
      <TextField type="password" name="password" bind:value="{form.password}">
        <span slot="label">{$l('Password')}</span>
        <p class="help" slot="help">{$l('Hint: Use a phrase from a book.')}</p>
      </TextField>

      <div class="form-actions">
        <Button icon="save" op="{registerOp}"><span>{mode == 'recover' ? $l('Set new password') : $l('Sign up')}</span></Button>
        {#if !settings('first_user')}
          <Link href="/login">{$l('Sign in')}</Link>
        {/if}
      </div>

      <OperationStatus op="{registerOp}" success="Loading Convos..."/>
    {:else if mode == 'login'}
      <h2>{$l('Sign in')}</h2>
      <TextField type="email" name="email" bind:value="{form.email}" placeholder="{$l('Ex: john@doe.com')}">
        <span slot="label">{$l('Email')}</span>
      </TextField>
      <TextField type="password" name="password" bind:value="{form.password}" autocomplete="current-password">
        <span slot="label">{$l('Password')}</span>
        <p class="help" slot="help">{@html $lmd('Contact your [Convos admin](%1) if you have forgotten your password.', settings('contact'))}</p>
      </TextField>

      <div class="form-actions">
        <Button icon="sign-in-alt" op="{loginOp}"><span>{$l('Sign in')}</span></Button>
        <Link href="/register">{$l('Sign up')}</Link>
      </div>

      <OperationStatus op="{loginOp}" success="Loading Convos..."/>
    {:else}
      <h2>{$l('Sign up')}</h2>
      <p>{$l('Please ask your Convos admin for an invite link to sign up, or sign in if you already have an account.')}</p>
      <div class="form-actions">
        <a class="btn" href="{settings('contact')}"><Icon name="paper-plane"/> {$l('Contact admin')}</a>
        <Link href="/login">{$l('Sign in')}</Link>
      </div>
    {/if}
  </form>
</main>

<div class="footer--wrapper is-small">
  <footer class="footer language-selector">
    <Icon name="globe"/>
    {#each $i18n.languageOptions as lang}
      <a href="#{lang[0]}" on:click="{() => $i18n.load(lang[0])}">{lang[1]}</a>
    {/each}
  </footer>
</div>
