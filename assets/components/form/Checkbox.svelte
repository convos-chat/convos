<script>
import {uuidv4} from '../../js/util';
import Icon from '../Icon.svelte';

export let checked = false;
export let disabled = false;
export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let value = 1;

let inputEl;
let hasFocus = false;

$: icon = checked ? 'check-square' : 'square';

$: if (inputEl && !inputEl.syncValue) {
  inputEl.syncValue = function() { [checked, value] = [this.checked, this.value] };
  inputEl.syncValue();
}
</script>

<div class="checkbox" class:has-focus="{hasFocus}" class:is-disabled="{disabled}" hidden="{hidden}">
  <input type="checkbox"
    id="{id}"
    name="{name}"
    value="{value}"
    bind:checked="{checked}"
    bind:this="{inputEl}"
    disabled="{disabled}"
    on:blur="{() => {hasFocus = false}}"
    on:focus="{() => {hasFocus = true}}"/>
  <Icon family="regular" name="{icon}" on:click="{() => { disabled || (checked = !checked) }}"/>
  <label for="{id}"><slot name="label">Label</slot></label>
</div>
