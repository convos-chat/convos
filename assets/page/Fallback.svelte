<script>
import Icon from '../components/Icon.svelte';
import {getContext} from 'svelte';
import {l, lmd} from '../js/i18n';
import {route} from '../store/Route';

export let status = route.path.split('/').pop() || 'not_found';

const user = getContext('user');
const loadingStatus = process.env.load_user ? ['loading', 'pending'] : ['loading'];

const messages = {
  'loading': 'Loading',
  'not_found': 'Not Found',
  'offline': 'Oops! You appear to be offline',
  'unknown': 'Unknown error!',
};

$: realStatus = messages[status] ? status : 'not_found';

route.update({title: l(messages[realStatus])});
</script>

<main class="welcome-screen">
  <article class="welcome-screen_fallback">
    <h1>
      <a href="{$route.baseUrl}"><span>{l(realStatus == 'loading' ? 'Convos' : messages[realStatus])}</span></a>
      {#if process.env.organization_name != 'Convos'}
        {#if process.env.organization_url != 'https://convos.chat'}
          <small class="subtitle">{realStatus == 'loading' ? '' : l('Convos')} {@html lmd('for [%1](%2)', process.env.organization_name, process.env.organization_url)}</small>
        {:else}
          <small class="subtitle">{realStatus == 'loading' ? '' : l('Convos')} {l('for %1', process.env.organization_name)}</small>
        {/if}
      {/if}
    </h1>

    {#if realStatus == 'loading'}
      <p>{l('Convos is the simplest way to use IRC, and it keeps you always online.')}</p>
      <p><i class="fas fa-download"></i> {l('Downloading Convos...')}</p>
      <p><i class="fas fa-rocket"></i> {l('Starting Convos...')}</p>
      <p><i class="fas fa-spinner fa-spin"></i> {l('Loading user data...')}</p>
      <p><a class="btn" href="{process.env.contact}">{l('Contact admin')}</a></p>
    {:else if realStatus == 'not_found'}
      <p>{l('The Convos Team have been searching and searching, but the requested page could not be found.')}</p>
      <p><a href="{$route.baseUrl}" target="_self" class="btn"><Icon name="play"/> {l('Go to start page')}</a></p>
    {:else if realStatus == 'offline'}
      <p><i class="fas fa-exclamation-triangle"></i> {l('Unable to connect to Convos. Please try again later or check your network connection.')}</p>
      <p><a href="{location.href}" target="_self" class="btn"><Icon name="sync-alt"/> {l('Retry')}</a></p>
    {:else}
      <p>{@html lmd('Yikes! we are so sorry for the inconvenience. Please submit an [issue](%1), if the problem does not go away.', 'https://github.com/nordaaker/convos/issues')}</p>
      <p><a href="{$route.baseUrl}" target="_self" class="btn"><Icon name="play"/> {l('Go to start page')}</a></p>
    {/if}
  </article>

  <footer class="welcome-screen__footer">
    <a href="https://convos.chat/" target="_blank">Convos</a>
    &mdash;
    <a href="https://convos.chat/blog" target="_blank">{l('Blog')}</a>
    &mdash;
    <a href="https://convos.chat/doc" target="_blank">{l('Documentation')}</a>
    &mdash;
    <a href="https://github.com/Nordaaker/convos" target="_blank">{l('GitHub')}</a>
  </footer>
</main>
