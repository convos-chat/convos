<script>
import Icon from '../Icon.svelte';
import Operation from '../../store/Operation';
import Time from '../../js/Time';

const minLoadingTime = 700;

let animation = '';
let className = '';
let classNames = [];
let forceDisable = false;
let t0 = 0;

export {className as class};
export let disabled = false;
export let icon = '';
export let op = new Operation({api: false, id: ''});
export let type = '';

$: $op.is('loading') && loadingState(true);
$: $op.is('loading') || setTimeout(() => loadingState(false), minLoadingTime - (new Time().toEpoch() - t0));

$: classNames = ['btn', 'for-' + (icon || 'default')].concat(className);
$: disabledProp = disabled || forceDisable;

function loadingState(loading) {
  if (loading) t0 = new Time().toEpoch();
  animation = loading ? 'spin' : '';
  forceDisable = loading;
}
</script>

<button class="{classNames.join(' ')}" disabled="{disabledProp}" type="{type}" on:click>
  <Icon {animation} name="{icon}"/>
  <slot/>
</button>
