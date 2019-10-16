<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {activeMenu} from '../store/router';

export let href = false;
export let icon = 'cog';

function clicked(e) {
  const aEl = e.target.closest('a');
  if (aEl && aEl.classList.contains('sidebar__item__link')) $activeMenu = '';
}
</script>

<div class="sidebar__item" on:click="{clicked}">
  <Link href="{href}" native="{!!href.indexOf('.html')}">
    <Icon name="{icon}"/>
    <slot/>
  </Link>
</div>
