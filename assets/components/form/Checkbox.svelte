<script>
import Icon from '../Icon.svelte';
import {uuidv4} from '../../js/util';

export let disabled = false;
export let form;
export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();

const checked = form.field(name);
let hasFocus = false;

$: icon = $checked ? 'check-square' : 'square';
</script>

<div class="checkbox" class:has-focus="{hasFocus}" class:is-disabled="{disabled}" hidden="{hidden}">
  <input type="checkbox"
    id="{id}"
    name="{name}"
    disabled="{disabled}"
    bind:checked="{$checked}"
    on:blur="{() => {hasFocus = false}}"
    on:focus="{() => {hasFocus = true}}"/>
  <Icon family="regular" name="{icon}" on:click="{() => { disabled || ($checked = !$checked) }}"/>
  <label for="{id}"><slot name="label">Label</slot></label>
</div>
