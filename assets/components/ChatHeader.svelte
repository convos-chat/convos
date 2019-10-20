<script>
import Icon from '../components/Icon.svelte';
import {activeMenu, gotoUrl} from '../store/router';
import {onMount} from 'svelte';

$: if (!$activeMenu && location.href.indexOf('#settings') != -1) {
  gotoUrl(location.href.replace(/#settings/, ''));
}

function toggleMenu() {
  $activeMenu = $activeMenu ? '' : 'nav';
}
</script>

<header class="chat-header">
  <slot/>
  <a href="#toggle:menu" class="chat-header__hamburger" on:click|preventDefault="{toggleMenu}"><Icon name="{$activeMenu ? 'times-circle' : 'bars'}"/></a>
</header>

