<script>
import Icon from './Icon.svelte';
import {activeMenu, viewport} from '../store/viewport';
import {getContext} from 'svelte';

const notifications = getContext('user').notifications;
</script>

<header class="chat-header">
  <slot/>
  {#if !$viewport.hasLeftColumn}
    <a href="#nav" class="btn-hallow can-toggle" class:is-active="{$activeMenu === 'nav'}" on:click="{activeMenu.toggle}">
      <Icon name="bars"/><Icon name="times"/>
      <small class="badge is-important" hidden="{!$notifications.notifications}">{$notifications.notifications}</small>
    </a>
  {/if}
</header>
