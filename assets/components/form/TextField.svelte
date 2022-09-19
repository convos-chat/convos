<script>
import Icon from '../Icon.svelte';
import {uuidv4} from '../../js/util';

let visible = false;

export let autocomplete = null;
export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let readonly = false;
export let type = 'text';
export let value;

function onInput(e) {
  value = type.match(/^(number|range)$/) ? parseInt(e.target.value, 10) : e.target.value;
}
</script>

<div class="text-field" class:has-password="{type === 'password'}" hidden="{hidden}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <input type="{visible ? 'text' : type}"
    id="{id}"
    name="{name}"
    autocomplete="{autocomplete}"
    placeholder="{placeholder}"
    readonly="{readonly}"
    value="{value}"
    on:input={onInput}
    on:keyup/>
  {#if type === 'password' && !readonly}
    <a href="#toggle" class="text-field__toggle" on:click|preventDefault="{() => { visible = !visible }}"><Icon name="{visible ? 'eye-slash' : 'eye'}"/></a>
  {/if}
</div>
<slot name="help"></slot>
