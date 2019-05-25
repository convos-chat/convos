<script>
import {uuidv4} from '../../js/util';

export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let value = '';
</script>

<div class="text-field">
  <label for="{id}"><slot name="label">Label</slot></label>
  <input type="text" {name} {placeholder} {id} bind:value/>
</div>