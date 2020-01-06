<script>
import {uuidv4} from '../../js/util';

export let autocomplete = 'off';
export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let readonly = false;
export let value = '';
</script>

<div class="text-field has-password" hidden="{hidden}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <input type="password" {name} {id} {placeholder} {readonly} {autocomplete} bind:value/>
</div>
