<script>
import {uuidv4} from '../../js/util';

export let className = '';
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let readonly = false;
export let value = '';

let inputEl;

$: classNames = ['text-area', className].filter(c => c.length);
$: if (inputEl) inputEl.value = value;
</script>

<div class="{classNames.join(' ')}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <textarea {name} {placeholder} {id} {readonly} bind:this="{inputEl}" bind:value></textarea>
</div>

