<script>
import {uuidv4} from '../../js/util';
import Icon from '../Icon.svelte';

export let checked = false;
export let disabled = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let value = 1;

let inputEl;

$: icon = checked ? 'check-square' : 'square';

$: if (inputEl && !inputEl.syncValue) {
  inputEl.syncValue = function() { [checked, value] = [this.checked, this.value] };
  inputEl.syncValue();
}
</script>

<div class="checkbox" class:is-disabled="{disabled}">
  <input type="checkbox" {disabled} {name} {id} {value} bind:checked="{checked}" bind:this="{inputEl}"/>
  <Icon family="regular" name="{icon}" on:click="{() => { disabled || (checked = !checked) }}"/>
  <label for="{id}"><slot name="label">Label</slot></label>
</div>
