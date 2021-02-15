<script>
import Icon from './Icon.svelte';
import {activeMenu, nColumns} from '../store/writable';
import {getContext} from 'svelte';

const user = getContext('user');
</script>

<header class="chat-header">
  <slot/>
  {#if $nColumns <= 1}
    <a href="#nav" class="btn-hallow" class:is-active="{$activeMenu == 'nav'}" on:click="{activeMenu.toggle}">
      <Icon name="bars"/>
      <Icon name="times"/>
      <small class="badge is-important" hidden="{!$user.unread}">{$user.unread}</small>
    </a>
  {/if}
</header>
