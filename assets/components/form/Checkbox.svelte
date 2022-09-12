<script>
import Icon from '../Icon.svelte';
import {uuidv4} from '../../js/util';

export let badge = false;
export let disabled = false;
export let hidden = false;
export let icon = 'square';
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let value;

let hasFocus = false;

$: icons = icon == 'caret' ? ['caret-square-down', 'caret-square-up'] : ['square', 'check-square'];
$: stateIcon = icons[value ? 1 : 0];
</script>

<label class="checkbox" class:has-badge="{badge}" class:has-focus="{hasFocus}" class:is-disabled="{disabled}" hidden="{hidden}">
  <input type="checkbox"
    id="{id}"
    name="{name}"
    checked="{value ? true : false}"
    disabled="{disabled}"
    on:blur="{() => {hasFocus = false}}"
    on:change="{(e) => {value = e.target.checked}}"
    on:focus="{() => {hasFocus = true}}"/>
  <Icon family="regular" name="{stateIcon}"/>
  <slot name="label"/>
</label>
