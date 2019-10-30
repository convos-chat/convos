<script>
import Icon from '../components/Icon.svelte';
import {activeMenu} from '../store/router';
import {getContext} from 'svelte';

const user = getContext('user');

$: unread = $user.unread;
</script>

<header class="chat-header">
  <slot/>
  <a href="#activeMenu:{$activeMenu ? '' : 'nav'}" class="chat-header__hamburger">
    <Icon name="{$activeMenu ? 'times-circle' : 'bars'}"/>
    <small class="chat-header__unread" hidden="{!unread}">{unread}</small>
  </a>
</header>

