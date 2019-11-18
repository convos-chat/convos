<script>
import {getContext, onMount} from 'svelte';
import {l} from '../js/i18n';
import {replaceClassName} from '../js/util';

const settings = getContext('settings');
const user = getContext('user');
const loadingStatus = settings.load_user ? ['loading', 'pending'] : ['loading'];

const messages = {
  'loading': 'Loading',
  'not_found': 'Not found',
  'offline': 'You appear to be offline',
};

$: status = $user.is('offline') ? 'offline' : $user.is(loadingStatus) ? 'loading' : 'not_found';

onMount(() => {
  replaceClassName('body', /(is-logged-)\S+/, 'out');
  replaceClassName('body', /(page-)\S+/, status);
});
</script>

<main class="main align-content-middle">
  <div>
    <h2>{l(messages[status])}</h2>
    {#if status == 'offline'}
      <p><i class="fas fa-exclamation-triangle"></i> {l('You seem to have lost connection to the internet.')}</p>
      <p><a href="/" class="btn">{l('Reload')}</a></p>
    {:else if status == 'loading'}
      <i class="fas fa-spinner fa-spin"></i>
      {l('Starting Convos...')}
    {:else if status == 'not_found'}
      <p>{l('Could not find the page you are looking for. Maybe you entered an invalid URL?')}</p>
      <p><a href="/" class="btn">{l('Go to landing page')}</a></p>
    {:else}
      <p>
        {l('This should not happen.')}
        Please submit <a href="https://github.com/Nordaaker/convos/issues/">an issue</a>,
        if the problem does not go away.
      </p>
      <p><a href="/" class="btn">{l('Go to landing page')}</a></p>
    {/if}
  </div>
</main>
