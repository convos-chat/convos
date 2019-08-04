<script>
import {uuidv4} from '../../js/util';
import Icon from '../Icon.svelte';

export let checked = false;
export let disabled = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();

$: icon = checked ? 'check-square' : 'minus-square';
</script>

<div class="checkbox" class:is-disabled="{disabled}">
  <input type="checkbox" {disabled} {name} {id} bind:checked="{checked}"/>
  <Icon name="{icon}" on:click="{() => { disabled || (checked = !checked) }}"/>
  <label for="{id}"><slot name="label">Label</slot></label>
</div>
