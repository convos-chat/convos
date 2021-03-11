<script>
import Icon from '../components/Icon.svelte';
import {getContext} from 'svelte';
import {l, lmd} from '../store/I18N';
import {route} from '../store/Route';
import {settings} from '../js/util';

export let title = 'Loading...';

const messages = {'loading': 'Loading...', 'not_found': 'Not Found'};
const socket = getContext('socket');
const user = getContext('user');

$: status = calculateStatus($route, $user);
$: title = messages[status];

function calculateStatus($route, user) {
  const override = $route.path.match(/\/err\/(\w+)/);
  return override ? override[1] : !$route.component || user.is('loading') ? 'loading' : 'not_found';
}
</script>

<main class="cms-main">
  <h2>{$l(messages[status])}</h2>
  {#if status == 'loading'}
    <p><Icon name="download"/> {$l('Downloaded Convos.')}</p>
    <p><Icon name="rocket"/> {$l('Started Convos.')}</p>
    {#if $socket.error}
      <p><Icon name="exclamation-triangle"/> {$l('Loading user data failed: %1', $l($socket.error))}</p>
    {:else}
      <p><Icon name="spinner fa-spin"/> {$l('Loading user data...')}</p>
    {/if}
    <p><a class="btn" href="{settings('contact')}"><Icon name="paper-plane"/> {$l('Contact admin')}</a></p>
  {:else if status == 'not_found'}
    <p>{$l('The Convos Team have been searching and searching, but the requested page could not be found.')}</p>
    <p><a href="{$route.baseUrl}" target="_self" class="btn"><Icon name="play"/> {$l('Go to start page')}</a></p>
  {:else}
    <p>{@html $lmd('Yikes! we are so sorry for the inconvenience. Please submit an [issue](%1), if the problem does not go away.', 'https://github.com/convos-chat/convos/issues')}</p>
    <p><a href="{$route.baseUrl}" target="_self" class="btn"><Icon name="play"/> {$l('Go to start page')}</a></p>
  {/if}
</main>
