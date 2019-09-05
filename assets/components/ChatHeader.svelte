<script>
import {gotoUrl, showMenu} from '../store/router';
import {onMount} from 'svelte';
import Icon from '../components/Icon.svelte';

function toggleMenu() {
  if (location.href.indexOf('#settings') != -1) {
    $showMenu = true;
    gotoUrl(location.href.replace(/#.*/, ''));
  }
  else {
    $showMenu = !$showMenu;
  }
}

onMount(() => {$showMenu = false});
</script>

<header class="header">
  <slot/>
  <a href="#toggle:menu" class="header__hamburger" on:click|preventDefault="{toggleMenu}"><Icon name="bars"/></a>
</header>

