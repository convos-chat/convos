<script>
import {uuidv4} from '../../js/util';

export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let placeholder = '';
export let readonly = false;
export let value;
</script>

<div class="text-area" hidden="{hidden}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <textarea
    id="{id}"
    name="{name}"
    placeholder="{placeholder}"
    readonly="{readonly}"
    bind:value="{value}"></textarea>
</div>
