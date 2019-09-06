<script>
import {epoch} from '../../js/util';
import Icon from '../Icon.svelte';
import Operation from '../../store/Operation';

export let className = '';
export let disabled = false;
export let icon = '';
export let op = new Operation({api: false, id: ''});
export let type = '';

const minLoadingTime = 700;

let animation = '';
let classNames = [];
let forceDisable = false;
let t0 = 0;

$: $op.is('loading') && loadingState(true);
$: $op.is('loading') || setTimeout(() => loadingState(false), minLoadingTime - (epoch() - t0));
$: disabledProp = disabled || forceDisable;

$: {
  classNames = ['btn'];
  classNames.push('for-' + (icon || 'default'));
}

function loadingState(loading) {
  if (loading) t0 = epoch();
  animation = loading ? 'spin' : '';
  forceDisable = loading;
}
</script>

<button class="{classNames.join(' ')}" disabled="{disabledProp}" {type} on:click>
  <slot/>
  <Icon {animation} name="{icon}"/>
</button>
