<script>
import {uuidv4} from '../../js/util';

let inputEl;

export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let readonly = false;
export let value = '';

$: if (inputEl && !inputEl.syncValue) {
  inputEl.syncValue = function() { value = this.value };
  inputEl.syncValue();
}
</script>

<div class="text-area" hidden="{hidden}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <textarea {name} {placeholder} {id} {readonly} bind:this="{inputEl}" bind:value></textarea>
</div>
