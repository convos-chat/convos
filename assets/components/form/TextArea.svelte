<script>
import {uuidv4} from '../../js/util';

export let className = '';
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let readonly = false;
export let value = '';

$: classNames = ['text-area', className].filter(c => c.length);
</script>

<div class="{classNames.join(' ')}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <textarea {name} {placeholder} {id} {readonly} bind:value></textarea>
</div>

