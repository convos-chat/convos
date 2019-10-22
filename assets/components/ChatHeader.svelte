<script>
import Icon from '../components/Icon.svelte';
import {activeMenu} from '../store/router';
</script>

<header class="chat-header">
  <slot/>
  <a href="#activeMenu:{$activeMenu ? '' : 'nav'}" class="chat-header__hamburger"><Icon name="{$activeMenu ? 'times-circle' : 'bars'}"/></a>
</header>

