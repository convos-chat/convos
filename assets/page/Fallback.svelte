<script>
import Icon from '../components/Icon.svelte';
import {fade} from 'svelte/transition';
import {getContext, onDestroy} from 'svelte';
import {l, lmd} from '../store/I18N';
import {route} from '../store/Route';
import {settings, timer} from '../js/util';

export let title = 'Loading...';

const messages = {'loading': 'Loading...', 'not_found': 'Not Found'};
const socket = getContext('socket');
const user = getContext('user');
const timeout = timer(5000);

let secondsLeft = 0;
let countdownTid;

$: status = calculateStatus($route, $user);
$: startHref = route.urlFor(user.email ? '/chat' : '/login');
$: title = messages[status];
$: updateCountdown($socket.reconnectAt);

function updateCountdown(reconnectAt) {
  clearInterval(countdownTid);
  secondsLeft = 0;
  if (!reconnectAt) return;

  const tick = () => { secondsLeft = Math.max(0, Math.ceil((reconnectAt - Date.now()) / 1000)) };
  tick();
  countdownTid = setInterval(tick, 500);
}

onDestroy(() => clearInterval(countdownTid));

function calculateStatus($route, user) {
  const override = $route.path.match(/\/err\/(\w+)/);
  return override ? override[1] : user.is('pending') || user.is('loading') ? 'loading' : 'not_found';
}
</script>

<main class="cms-main">
  <h2>{$l(messages[status])}</h2>
  {#if status === 'loading'}
    <p><Icon name="download"/> {$l('Downloaded Convos.')}</p>
    <p><Icon name="rocket"/> {$l('Started Convos.')}</p>
    {#if $socket.error}
      <p>
        <Icon name="exclamation-triangle"/>
        {navigator.onLine === false ? $l('You appear to be offline.') : $l('The Convos server appears to be unreachable.')}
      </p>
      {#if secondsLeft > 0}
        <p><Icon name="spinner fa-spin"/> {$l('Retrying in %1s...', secondsLeft)}</p>
      {:else}
        <p><Icon name="spinner fa-spin"/> {$l('Connecting...')}</p>
      {/if}
    {:else}
      <p><Icon name="spinner fa-spin"/> {$l('Loading user data...')}</p>
    {/if}
    <p>
      <a class="btn" href="{settings('contact')}"><Icon name="paper-plane"/> {$l('Contact admin')}</a>
      {#await timeout}
        <!-- Go to start page -->
      {:then}
        <a href="{startHref}" target="_self" class="btn is-secondary" transition:fade><Icon name="redo"/> {$l('Retry')}</a>
      {/await}
    </p>
  {:else if status === 'not_found'}
    <p>{$l('The Convos Team have been searching and searching, but the requested page could not be found.')}</p>
    <p><a href="{startHref}" target="_self" class="btn"><Icon name="play"/> {$l('Go to start page')}</a></p>
  {:else}
    <p>{@html $lmd('Yikes! we are so sorry for the inconvenience. Please submit an [issue](%1), if the problem does not go away.', 'https://github.com/convos-chat/convos/issues')}</p>
    <p><a href="{startHref}" target="_self" class="btn"><Icon name="play"/> {$l('Go to start page')}</a></p>
  {/if}
</main>
