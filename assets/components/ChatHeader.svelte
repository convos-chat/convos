<script>
import Icon from '../components/Icon.svelte';
import {activeMenu} from '../store/writable';
import {getContext} from 'svelte';

const user = getContext('user');
</script>

<header class="chat-header">
  <slot/>
  <a href="#nav" on:click="{activeMenu.toggle}" class="btn is-hamburger can-toggle" class:is-toggled="{$activeMenu == 'nav'}">
    <Icon name="bars"/>
    <Icon name="times"/>
    <small class="chat-header__unread" hidden="{!$user.unread}">{$user.unread}</small>
  </a>
</header>
