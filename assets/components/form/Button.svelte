<script>
import Icon from '../Icon.svelte';
import Operation from '../../store/Operation';
import Time from '../../js/Time';

const minLoadingTime = 700;

let animation = '';
let classNames = [];
let forceDisable = false;
let t0 = 0;

export let disabled = false;
export let icon = '';
export let op = new Operation({api: false, id: ''});
export let tooltip = '';
export let type = '';

$: $op.is('loading') && loadingState(true);
$: $op.is('loading') || setTimeout(() => loadingState(false), minLoadingTime - (new Time().toEpoch() - t0));

$: classNames = ['btn', 'for-' + (icon || 'default')];
$: disabledProp = disabled || forceDisable;

function loadingState(loading) {
  if (loading) t0 = new Time().toEpoch();
  animation = loading ? 'spin' : '';
  forceDisable = loading;
}
</script>

<button class="{classNames.join(' ')}" class:has-tooltip="{!!tooltip.length}" disabled="{disabledProp}" {type} data-tooltip="{tooltip}" on:click>
  <Icon {animation} name="{icon}"/>
  <slot/>
</button>
