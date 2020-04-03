<script>
import {getContext} from 'svelte';
import {route} from '../store/Route';

const user = getContext('user');

$: redirect($user);

function redirect(user) {
  const dialog = user.dialogs()[0];
  const defaultPath = dialog ? dialog.path : '/chat';

  return user.is('loading') ? null
    : !user.is('authenticated') ? route.go('/login')
    : route.go(!route.lastUrl || route.lastUrl == route.canonicalPath ? defaultPath : route.lastUrl, {}, true);
}
</script>
