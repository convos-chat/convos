<script>
import Button from '../components/form/Button.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import ScrollSpy from '../js/ScrollSpy';
import TextField from '../components/form/TextField.svelte';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';
import {q} from '../js/util';
import {route} from '../store/Route';

const emailFromParams = location.href.indexOf('email=') != -1;
const user = getContext('user');
const scrollSpy = new ScrollSpy();
const loginOp = user.api.operation('loginUser');
const registerOp = user.api.operation('registerUser');

let formEl;
let mainEl;
let observer;

$: defaultPos = $route.path.indexOf('register') == -1 ? 0 : '#signup';
$: scrollSpy.wrapper = mainEl;
$: scrollSpy.scrollTo($route.hash ? '#' + $route.hash : 0);

$: if ($loginOp.is('success')) {
  redirectAfterLogin(loginOp);
}

$: if ($registerOp.is('success')) {
  route.update({lastUrl: ''}); // Make sure the old value is forgotten
  redirectAfterLogin(registerOp);
}

onMount(() => {
  if (!observer) {
    const threshold = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];
    observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        const ratio = entry.intersectionRatio;
        entry.target.style.opacity = ratio > 0.9 ? 1 : ratio ? (ratio - 0.25) : 1;
      });
    }, {threshold});
    q(document, '.fade-in', el => observer.observe(el));
  }

  if (formEl) route.urlToForm(formEl);
});

async function redirectAfterLogin(op) {
  document.cookie = op.res.headers['Set-Cookie'];
  op.reset();
  await user.load();
  route.go('/');
}
</script>

<main id="top" class="welcome-screen" bind:this="{mainEl}">
  <article class="welcome-screen__about">
    <h1>
      <Link href="/"><span>{l('Convos')}</span></Link>
      {#if process.env.organization_name != 'Convos'}
        {#if process.env.organization_url != 'https://convos.by'}
          <small class="subtitle">{@html lmd('for [%1](%2)', process.env.organization_name, process.env.organization_url)}</small>
        {:else}
          <small class="subtitle">{l('for %1', process.env.organization_name)}</small>
        {/if}
      {/if}
    </h1>

    <p>{l('Convos is the simplest way to use IRC, and it keeps you always online.')}</p>
  </article>

  {#if !$user.isFirst}
    <section id="signin" class="welcome-screen__signin fade-in">
      <form method="post" on:submit|preventDefault="{e => loginOp.perform(e.target)}">
        <h2>{l('Sign in')}</h2>
        <TextField type="email" name="email" placeholder="{l('Ex: john@doe.com')}" bind:value="{user.formEmail}">
          <span slot="label">{l('E-mail')}</span>
        </TextField>

        <TextField type="password" name="password" autocomplete="current-password">
          <span slot="label">{l('Password')}</span>
        </TextField>

        <div class="form-actions">
          <Button icon="sign-in-alt" op="{loginOp}">{l('Sign in')}</Button>
          <a class="btn is-hallow" on:click="{scrollSpy.scrollTo}" href="#signup">{l('Sign up')}</a>
        </div>

        <OperationStatus op="{loginOp}"/>
      </form>
    </section>
  {/if}

  <section id="signup" class="welcome-screen__signup fade-in">
    {#if process.env.status >= 400}
      <h2>{l('Invalid invite/recover URL')}</h2>
      <p>{l(process.env.status == 410 ? 'The link has expired.' : 'The link is invalid.')}</p>
      <p>{l('Please ask your Convos admin for a new link.')}</p>
      <p>
        <a class="btn" href="{process.env.contact}">{l('Contact admin')}</a>
        <a class="btn is-hallow" on:click="{scrollSpy.scrollTo}" href="#signin">{l('Sign in')}</a>
        <a class="btn is-hallow" on:click="{scrollSpy.scrollTo}" href="#top">{l('Home')}</a>
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
          <Button icon="save" op="{registerOp}">{l(process.env.existing_user ? 'Set new password' : 'Sign up')}</Button>
        </div>

        {#if !emailFromParams && !$user.isFirst}
          <p on:click="{scrollSpy.scrollTo}">{@html lmd('Go and [sign in](%1) if you already have an account.', '#signin')}</p>
        {/if}

        <OperationStatus op="{registerOp}"/>
      </form>
    {:else}
      <h2>{l('Sign up')}</h2>
      <p>{l('Convos is not open for public registration.')}</p>
      <p on:click="{scrollSpy.scrollTo}">{l('Please ask your Convos admin for an invite link to sign up, or sign in if you already have an account.')}</p>
      <div class="form-actions">
        <a class="btn" href="{process.env.contact}">{l('Contact admin')}</a>
        <a class="btn is-hallow" on:click="{scrollSpy.scrollTo}" href="#signin">{l('Sign in')}</a>
        <a class="btn is-hallow" on:click="{scrollSpy.scrollTo}" href="#top">{l('Home')}</a>
      </div>
    {/if}
  </section>

  <footer class="welcome-screen__footer fade-in">
    <Link href="https://convos.by/">Convos</Link>
    &mdash;
    <Link href="https://convos.by/blog">{l('Blog')}</Link>
    &mdash;
    <Link href="https://convos.by/doc">{l('Documentation')}</Link>
    &mdash;
    <Link href="https://github.com/Nordaaker/convos">{l('GitHub')}</Link>
  </footer>
</main>
