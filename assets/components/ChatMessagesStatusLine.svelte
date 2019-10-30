<script>
import Icon from '../components/Icon.svelte';

let className = '';

export {className as class};
export let icon = '';
export let animation = '';

</script>

<div class="message-status-line {className}">
  <span>
    <Icon name="{icon}" animation="{animation}"/>
    <slot/>
  </span>
</div>