<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ConnectionForm from '../components/ConnectionForm.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {l} from '../store/I18N';

export let connection_id = 'add';
export const title = connection_id == 'add' ? 'Add connection' : 'Edit connection';
</script>

<ChatHeader>
  <h1>{connection_id == 'add' ? $l('Add connection') : $l('Edit connection')}</h1>
  <Link href="/settings/connections" class="btn-hallow is-active" data-tooltip="{$l('See all connections')}"><Icon name="list"/><Icon name="times"/></Link>
</ChatHeader>

<main class="main">
  <ConnectionForm id="{connection_id}" is_page="{true}"/>
</main>
