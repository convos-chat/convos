<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';

export let href = false;
export let icon = 'cog';
</script>

<div class="sidebar__item">
  <Link href="{href}" class="sidebar__item__link" native="{href.indexOf('.html') != -1}">
    <Icon name="{icon}"/>
    <slot/>
  </Link>
</div>
