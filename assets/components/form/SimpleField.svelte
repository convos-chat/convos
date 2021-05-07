<script>
import {uuidv4} from '../../js/util';

export let form;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let type = 'hidden';

const value = form.field(name);
</script>

<input type="{type}" id="{id}" name="{name}" value="{$value}">
