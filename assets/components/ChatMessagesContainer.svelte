<script>
import Button from './form/Button.svelte';
import ChatDialogAdd from '../components/ChatDialogAdd.svelte';
import ChatMessage from './ChatMessage.svelte';
import ChatMessagesStatusLine from './ChatMessagesStatusLine.svelte';
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import {route} from '../store/Route';

export let dialog;
export let messagesHeight = 0;

const user = getContext('user');

$: connection = $user.findDialog({connection_id: dialog.connection_id}) || {};
</script>

<div class="messages-container" bind:offsetHeight="{messagesHeight}">
  {#if !dialog.connection_id || user.findDialog(dialog)}
    {#if $dialog.messages.length > 40 && $dialog.is('loading')}
      <ChatMessagesStatusLine class="for-loading" icon="spinner" animation="spin">{l('Loading...')}</ChatMessagesStatusLine>
    {/if}

    {#if $dialog.startOfHistory}
      <ChatMessagesStatusLine class="for-start-of-history" icon="calendar-alt">{l('Started chatting on %1', $dialog.startOfHistory.getHumanDate())}</ChatMessagesStatusLine>
    {/if}

    <slot/>

    {#if !$dialog.is('success') || (connection.is && connection.is('unreachable'))}
      <ChatMessagesStatusLine class="for-loading" icon="spinner" animation="spin"><a href="{route.baseUrl}" target="_self">{l('Loading...')}</a></ChatMessagesStatusLine>
    {/if}
  {:else}
    <ChatDialogAdd dialog="{dialog}"/>
  {/if}
</div>
