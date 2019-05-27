<script>
import Icon from '../components/Icon.svelte';
import {l} from '../js/i18n';

export let obj;

$: name = !obj                        ? 'question-circle'
        : obj.frozen                  ? 'unlink'
        : obj.state == 'connected'    ? 'check-circle'
        : obj.state == 'disconnected' ? 'unlink'
        : obj.state == 'queued'       ? 'sync-alt'
        : obj.state == 'loading'      ? 'circle-notch'
        :                               '';

$: title = obj.frozen || (obj.state == 'disconnected' ? l('Disconnected') : '');
</script>

{#if name}
  <Icon className="state-icon" {name} {title}/>
{/if}