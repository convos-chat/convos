<script>
import {onMount} from 'svelte';
import {uuidv4} from '../../js/util';

export let autocomplete = null;
export let className = '';
export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let readonly = false;
export let value = '';

let inputEl;

$: classNames = ['text-field', className].filter(c => c.length);
$: if (inputEl) inputEl.value = value;
</script>

<div class="{classNames.join(' ')}" hidden="{hidden}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <input type="text" {autocomplete} {name} {placeholder} {id} {readonly} bind:this="{inputEl}" bind:value on:keyup/>
</div>
