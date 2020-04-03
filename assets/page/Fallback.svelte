<script>
import Icon from '../components/Icon.svelte';
import {getContext} from 'svelte';
import {l, lmd} from '../js/i18n';
import {route} from '../store/Route';

const user = getContext('user');
const loadingStatus = process.env.load_user ? ['loading', 'pending'] : ['loading'];

const messages = {
  'loading': 'Loading',
  'not_found': 'Not Found',
  'offline': 'You appear to be offline',
  'unknown': 'Unknown error!',
};

$: status = calculateStatus($user, $route.pathParts);

function calculateStatus(user, pathParts) {
  const fromPath = pathParts.slice(-1)[0] || '';
  const status = messages[fromPath] ? fromPath : user.is('offline') ? 'offline' : user.is(loadingStatus) ? 'loading' : 'not_found';

  route.update({title: l(messages[status])});
  return status;
}
</script>

<main class="welcome-screen">
  <article class="welcome-screen_fallback">
    <h1>
      <a href="{$route.baseUrl}"><span>{l(status == 'loading' ? 'Convos' : messages[status])}</span></a>
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
      <p><a href="{$route.canonicalPath}" class="btn">{l('Reload')}</a></p>
    {:else if status == 'loading'}
      <p>{l('Convos is the simplest way to use IRC, and it keeps you always online.')}</p>
      <p><i class="fas fa-download"></i> {l('Downloading Convos...')}</p>
      <p><i class="fas fa-rocket"></i> {l('Starting Convos...')}</p>
      <p><i class="fas fa-spinner fa-spin"></i> {l('Loading user data...')}</p>
      <p><a class="btn" href="{process.env.contact}">{l('Contact admin')}</a></p>
    {:else if status == 'not_found'}
      <p>{l('The Convos Team have been searching and searching, but the requested page could not be found.')}</p>
      <p><a href="{$route.baseUrl}" class="btn"><Icon name="play"/> {l('Go to start page')}</a></p>
    {:else}
      <p>{@html lmd('Yikes! we are so sorry for the inconvenience. Please submit an [issue](%1), if the problem does not go away.', 'https://github.com/nordaaker/convos/issues')}</p>
      <p><a href="{$route.baseUrl}" class="btn"><Icon name="play"/> {l('Go to start page')}</a></p>
    {/if}
  </article>

  <footer class="welcome-screen__footer">
    <a href="https://convos.by/" target="_blank">Convos</a>
    &mdash;
    <a href="https://convos.by/blog" target="_blank">{l('Blog')}</a>
    &mdash;
    <a href="https://convos.by/doc" target="_blank">{l('Documentation')}</a>
    &mdash;
    <a href="https://github.com/Nordaaker/convos" target="_blank">{l('GitHub')}</a>
  </footer>
</main>
