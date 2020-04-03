<script>
import Icon from '../components/Icon.svelte';
import {currentUrl, docTitle} from '../store/router';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';
import {replaceClassName} from '../js/util';

const user = getContext('user');
const loadingStatus = process.env.load_user ? ['loading', 'pending'] : ['loading'];

const messages = {
  'loading': 'Loading',
  'not_found': 'Not Found',
  'offline': 'You appear to be offline',
  'unknown': 'Unknown error!',
};

$: status = calculateStatus($user, $currentUrl);

onMount(() => {
  replaceClassName('body', /(is-logged-)\S+/, 'out');
  replaceClassName('body', /(page-)\S+/, status);
});

function calculateStatus($user, $currentUrl) {
  const fromPath = $currentUrl.pathParts[$currentUrl.pathParts.length - 1] || '';
  const status = messages[fromPath] ? fromPath : $user.is('offline') ? 'offline' : $user.is(loadingStatus) ? 'loading' : 'not_found';

  $docTitle = l('%1 - Convos', l(messages[status]));
  return status;
}
</script>

<main class="welcome-screen">
  <article class="welcome-screen_fallback">
    <h1>
      <a href="{currentUrl}"><span>{l(status == 'loading' ? 'Convos' : messages[status])}</span></a>
      {#if process.env.organization_name != 'Convos'}
        {#if process.env.organization_url != 'https://convos.by'}
          <small class="subtitle">{status == 'loading' ? '' : l('Convos')} {@html lmd('for [%1](%2)', process.env.organization_name, process.env.organization_url)}</small>
        {:else}
          <small class="subtitle">{status == 'loading' ? '' : l('Convos')} {l('for %1', process.env.organization_name)}</small>
        {/if}
      {/if}
    </h1>

    {#if status == 'offline'}
      <p><i class="fas fa-exclamation-triangle"></i> {l('Seems like we got disconnected from the internet.')}</p>
      <p><a href="{$currentUrl}" class="btn">{l('Reload')}</a></p>
    {:else if status == 'loading'}
      <p>{l('Convos is the simplest way to use IRC, and it keeps you always online.')}</p>
      <p><i class="fas fa-download"></i> {l('Downloading Convos...')}</p>
      <p><i class="fas fa-rocket"></i> {l('Starting Convos...')}</p>
      <p><i class="fas fa-spinner fa-spin"></i> {l('Loading user data...')}</p>
      <p><a class="btn" href="{process.env.contact}">{l('Contact admin')}</a></p>
    {:else if status == 'not_found'}
      <p>{l('The Convos Team have been searching and searching, but the requested page could not be found.')}</p>
      <p><a href="{$currentUrl.base}" class="btn"><Icon name="play"/> {l('Go to start page')}</a></p>
    {:else}
      <p>{@html lmd('Yikes! we are so sorry for the inconvenience. Please submit an [issue](%1), if the problem does not go away.', 'https://github.com/nordaaker/convos/issues')}</p>
      <p><a href="{$currentUrl.base}" class="btn"><Icon name="play"/> {l('Go to start page')}</a></p>
    {/if}
  </article>

  <footer class="welcome-screen__footer">
    <a href="https://convos.by/">Convos</a>
    &mdash;
    <a href="https://convos.by/blog">{l('Blog')}</a>
    &mdash;
    <a href="https://convos.by/doc">{l('Documentation')}</a>
    &mdash;
    <a href="https://github.com/Nordaaker/convos">{l('GitHub')}</a>
  </footer>
</main>
