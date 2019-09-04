<script>
import {uuidv4} from '../../js/util';

export let className = '';
export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let value = '';

$: classNames = ['text-field', 'has-password', className].filter(c => c.length);
</script>

<div class="{classNames.join(' ')}" hidden="{hidden}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <input type="password" {name} {id} {placeholder} bind:value/>
</div>
