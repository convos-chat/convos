<script>
import Icon from '../components/Icon.svelte';

export let className = '';
export let disabled = false;
export let icon = '';
export let type = '';

let classNames = [];

$: {
  classNames = ['btn'];
  classNames.push('for-' + (type || icon || 'default'));
}
</script>

<button class="{classNames.join(' ')}" {disabled} on:click>
  <slot/>
  <Icon name="{icon}"/>
</button>
