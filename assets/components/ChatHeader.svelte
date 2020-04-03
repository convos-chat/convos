<script>
import Icon from '../components/Icon.svelte';
import {getContext} from 'svelte';
import {route} from '../store/Route';

const user = getContext('user');
</script>

<header class="chat-header">
  <slot/>
  <a href="#activeMenu:{$route.activeMenu ? '' : 'nav'}" class="chat-header__hamburger">
    <Icon name="{$route.activeMenu ? 'times-circle' : 'bars'}"/>
    <small class="chat-header__unread" hidden="{!$user.unread}">{$user.unread}</small>
  </a>
</header>

