<script>
import Icon from '../components/Icon.svelte';

export let className = '';
export let disabled = false;
export let icon = '';
export let type = '';

let classNames = [];

$: {
  classNames = ['btn'];
  classNames.push('for-' + (icon || 'default'));
}
</script>

<button class="{classNames.join(' ')}" {disabled} {type} on:click>
  <slot/>
  <Icon name="{icon}"/>
</button>
