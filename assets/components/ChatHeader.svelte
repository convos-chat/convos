<script>
import Icon from '../components/Icon.svelte';
import {getContext} from 'svelte';
import {route} from '../store/Route';

const user = getContext('user');
</script>

<header class="chat-header">
  <slot/>
  <a href="#activeMenu:nav" class="btn is-hamburger can-toggle" class:is-toggled="{$route.activeMenu == 'nav'}">
    <Icon name="bars"/>
    <Icon name="times"/>
    <small class="chat-header__unread" hidden="{!$user.unread}">{$user.unread}</small>
  </a>
</header>

