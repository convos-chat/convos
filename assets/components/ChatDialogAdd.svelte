<script>
import Button from './form/Button.svelte';
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import {getContext} from 'svelte';
import {l} from '../js/i18n';

export let dialog = '';

const user = getContext('user');
</script>

{#if !user.findDialog({connection_id: dialog.connection_id})}
  <h2>{l('Connection does not exist.')}</h2>
  <p>{l('Do you want to create the connection "%1"?', dialog.connection_id)}</p>
  <p>
    <Link href="/settings/connection?server={encodeURIComponent(dialog.connection_id)}&dialog={encodeURIComponent(dialog.dialog_id)}" class="btn"><Icon name="thumbs-up"/> {l('Yes')}</Link>
    <Link href="/chat" class="btn"><Icon name="thumbs-down"/> {l('No')}</Link>
  </p>
{:else}
  <h2>{l('You are not part of this conversation.')}</h2>
  <p>{l('Do you want to chat with "%1"?', dialog.dialog_id)}</p>
  <p>
    <Button type="button" icon="thumbs-up" on:click="{() => dialog.send('/join ' + dialog.dialog_id)}"><span>{l('Yes')}</span></Button>
    <Link href="/chat" class="btn"><Icon name="thumbs-down"/><span>{l('No')}</span></Link>
  </p>
{/if}
