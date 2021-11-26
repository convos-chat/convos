<script>
import Icon from '../Icon.svelte';
import {uuidv4} from '../../js/util';

export let badge = false;
export let disabled = false;
export let form;
export let hidden = false;
export let icon = 'square';
export let name = '';
export let id = name ? 'form_' + name : uuidv4();

let hasFocus = false;

$: checked = form.field(name);
$: icons = icon == 'caret' ? ['caret-square-down', 'caret-square-up'] : ['square', 'check-square'];
$: stateIcon = icons[$checked ? 1 : 0];
</script>

<div class="checkbox" class:has-badge="{badge}" class:has-focus="{hasFocus}" class:is-disabled="{disabled}" hidden="{hidden}">
  <input type="checkbox"
    id="{id}"
    name="{name}"
    disabled="{disabled}"
    bind:checked="{$checked}"
    on:blur="{() => {hasFocus = false}}"
    on:focus="{() => {hasFocus = true}}"/>
  <Icon family="regular" name="{stateIcon}" on:click="{() => { disabled || ($checked = !$checked) }}"/>
  <label for="{id}"><slot name="label">Label</slot></label>
</div>
