<script>
import Button from '../components/form/Button.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import TextField from '../components/form/TextField.svelte';
import {currentUrl, gotoUrl, urlToForm} from '../store/router';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';
import {q, scrollTo} from '../js/util';

const emailFromParams = location.href.indexOf('email=') != -1;
const settings = getContext('settings');
const user = getContext('user');

const loginOp = user.api.operation('loginUser');
const registerOp = user.api.operation('registerUser');

let formEl;
let observer;

$: defaultPos = $currentUrl.path.indexOf('register') == -1 ? 0 : '#signup';
$: scrollTo($currentUrl.hash || defaultPos);

$: if ($loginOp.is('success')) {
  redirectAfterLogin(loginOp);
}

$: if ($registerOp.is('success')) {
  user.update({lastUrl: ''}); // Make sure the old value is forgotten
  redirectAfterLogin(registerOp);
}

onMount(() => {
  if (!observer) {
    observer = new IntersectionObserver(sectionObserved, {rootMargin: '-30px 0px 80px 0px', threshold: 0.8});
    q(document, '.fade-in', el => observer.observe(el));
  }

  if (formEl) urlToForm(formEl);
});

async function redirectAfterLogin(op) {
  document.cookie = op.res.headers['Set-Cookie'];
  op.reset();
  await user.load();
  gotoUrl(user.calculateLastUrl());
}

function sectionObserved(entries, observer) {
  entries.forEach(entry => {
    const classListMethod = entry.isIntersecting ? 'add' : 'remove';
    entry.target.classList[classListMethod]('is-visible');
  });
}
</script>

<main id="top" class="welcome-screen">
  <article class="welcome-screen__about">
    <h1>
      <Link href="/"><span>{l('Convos')}</span></Link>
      {#if settings.organization_name != 'Convos'}
        {#if settings.organization_url != 'https://convos.by'}
          <small class="subtitle">{@html lmd('for [%1](%2)', settings.organization_name, settings.organization_url)}</small>
        {:else}
          <small class="subtitle">{l('for %1', settings.organization_name)}</small>
        {/if}
      {/if}
    </h1>

    <p>{l('Convos is the simplest way to use IRC, and it keeps you always online.')}</p>
  </article>

  <section id="signin" class="welcome-screen__signin fade-in">
    <form method="post" on:submit|preventDefault="{e => loginOp.perform(e.target)}">
      <h2>{l('Sign in')}</h2>
      <TextField name="email" placeholder="{l('Ex: john@doe.com')}" bind:value="{user.formEmail}">
        <span slot="label">{l('E-mail')}</span>
      </TextField>

      <PasswordField autocomplete="on" name="password">
        <span slot="label">{l('Password')}</span>
      </PasswordField>

      <div class="form-actions">
        <Button icon="sign-in-alt" op="{loginOp}">{l('Sign in')}</Button>
        <a class="btn is-hallow" on:click="{scrollTo}" href="#signup">{l('Sign up')}</a>
      </div>

      <OperationStatus op="{loginOp}"/>
    </form>
  </section>

  <section id="signup" class="welcome-screen__signup fade-in">
    {#if settings.status >= 400}
      <h2>{l('Invalid invite/recover URL')}</h2>
      <p>{l(settings.status == 410 ? 'The link has expired.' : 'The link is invalid.')}</p>
      <p>{l('Please ask your Convos admin for a new link.')}</p>
      <p>
        <a class="btn" href="{settings.contact}">{l('Contact admin')}</a>
        <a class="btn is-hallow" on:click="{scrollTo}" href="#signin">{l('Sign in')}</a>
        <a class="btn is-hallow" on:click="{scrollTo}" href="#top">{l('Home')}</a>
      </p>
    {:else if emailFromParams || settings.open_to_public || settings.first_user}
      <h2>{l(settings.existing_user ? 'Recover account' : 'Sign up')}</h2>
      <form method="post" on:submit|preventDefault="{e => registerOp.perform(e.target)}" bind:this="{formEl}">
        <input type="hidden" name="exp">
        <input type="hidden" name="token">

        <TextField name="email" placeholder="{l('Ex: john@doe.com')}" readonly="{emailFromParams}" bind:value="{user.formEmail}">
          <span slot="label">{l('E-mail')}</span>

          <p slot="help">
            {#if emailFromParams}
              {l('Your email is from the invite link.')}
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
          <Button icon="save" op="{registerOp}">{l(settings.existing_user ? 'Set new password' : 'Sign up')}</Button>
        </div>

        {#if !emailFromParams}
          <p on:click="{scrollTo}">{@html lmd('Go and [sign in](%1) if you already have an account.', '#signin')}</p>
        {/if}

        <OperationStatus op="{registerOp}"/>
      </form>
    {:else}
      <h2>{l('Sign up')}</h2>
      <p>{l('Convos is not open for public registration.')}</p>
      <p on:click="{scrollTo}">{l('Please ask your Convos admin for an invite link to sign up, or sign in if you already have an account.')}</p>
      <div class="form-actions">
        <a class="btn" href="{settings.contact}">{l('Contact admin')}</a>
        <a class="btn is-hallow" on:click="{scrollTo}" href="#signin">{l('Sign in')}</a>
        <a class="btn is-hallow" on:click="{scrollTo}" href="#top">{l('Home')}</a>
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
