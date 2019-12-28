<script>
import {uuidv4} from '../../js/util';
import {onMount} from 'svelte';

export let autocomplete = 'off';
export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let readonly = false;
export let value = '';

let el;

onMount(() => {
  if (autocomplete == 'off') setInterval(() => { if (el && value.length == 0) el.value = ''; }, 100);
});
</script>

<div class="text-field has-password" hidden="{hidden}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <input type="password" {name} {id} {placeholder} {readonly} bind:this="{el}" bind:value/>
</div>
