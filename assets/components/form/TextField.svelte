<script>
import {uuidv4} from '../../js/util';

const onInput = e => { value = type.match(/^(number|range)$/) ? parseInt(e.target.value, 10) : e.target.value };
let inputEl;

export let autocomplete = null;
export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let readonly = false;
export let type = 'text';
export let value = '';

$: if (inputEl && !inputEl.syncValue) {
  inputEl.syncValue = function() { value = this.value };
  inputEl.syncValue();
}
</script>

<div class="text-field" class:has-password="{type == 'password'}" hidden="{hidden}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <input {type} {name} {id} {autocomplete} {placeholder} {readonly} {value} bind:this="{inputEl}" on:input={onInput} on:keyup/>
  <slot name="help"></slot>
</div>
