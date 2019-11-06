<script>
import Link from '../components/Link.svelte';
import SidebarLoggedout from '../components/SidebarLoggedout.svelte';
import {getContext, onMount} from 'svelte';
import {l} from '../js/i18n';
import {replaceClassName} from '../js/util';

const user = getContext('user');

const status = user.is('offline') ? 'offline' : user.is('loading') ? 'loading' : 'not_found';
const messages = {
  'loading': 'Loading',
  'not_found': 'Not found',
  'offline': 'You appear to be offline',
};

onMount(() => {
  replaceClassName('body', /(is-logged-)\S+/, 'out');
  replaceClassName('body', /(page-)\S+/, status);
});
</script>

<SidebarLoggedout/>

<main class="main align-content-middle">
  <div>
    <h2>{l(messages[status])}</h2>
    {#if status == 'offline'}
      <p><i class="fas fa-exclamation-triangle"></i> {l('You seem to have lost connection to the internet.')}</p>
      <p><Link href="/" class="btn">{l('Reload')}</Link></p>
    {:else if status == 'loading'}
      <i class="fas fa-spinner fa-spin"></i>
      {l('Starting Convos...')}
    {:else if status == 'not_found'}
      <p>{l('Could not find the page you are looking for. Maybe you entered an invalid URL?')}</p>
      <p><Link href="/" class="btn">{l('Go to landing page')}</Link></p>
    {:else}
      <p>
        {l('This should not happen.')}
        Please submit <a href="https://github.com/Nordaaker/convos/issues/">an issue</a>,
        if the problem does not go away.
      </p>
      <p><Link href="/" class="btn">{l('Go to landing page')}</Link></p>
    {/if}
  </div>
</main>
