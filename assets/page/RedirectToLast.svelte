<script>
import {getContext} from 'svelte';
import {route} from '../store/Route';

const user = getContext('user');

$: redirect($user);

function redirect(user) {
  const dialog = user.dialogs()[0];
  const url = route.lastUrl ? route.lastUrl : dialog ? dialog.path : '/settings/connection';
  return user.is('loading') ? null : !user.is('authenticated') ? route.go('/login') : route.go(url);
}
</script>
