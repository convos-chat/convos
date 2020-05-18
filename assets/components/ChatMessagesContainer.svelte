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
const omnibus = user.omnibus;

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

    {#if $omnibus.wantNotifications === null}
      <ChatMessage>
        {l('Do you want to be notified when someone sends you a private message?')}
        <br>
        <Button type="button" icon="thumbs-up" on:click="{() => omnibus.requestPermissionToNotify()}"><span>{l('Yes')}</span></Button>
        <Button type="button" icon="thumbs-down" on:click="{() => omnibus.requestPermissionToNotify(false)}"><span>{l('No')}</span></Button>
      </ChatMessage>
    {:else if typeof $omnibus.protocols.irc == 'undefined'}
      <ChatMessage>
        {l('Do you want %1 to handle "irc://" links?', l('Convos'))}
        <br>
        <Button type="button" icon="thumbs-up" on:click="{() => omnibus.registerProtocol('irc', true)}"><span>{l('Yes')}</span></Button>
        <Button type="button" icon="thumbs-down" on:click="{() => omnibus.registerProtocol('irc', false)}"><span>{l('No')}</span></Button>
      </ChatMessage>
    {/if}

    {#if !$dialog.is('success') || (connection.is && connection.is('unreachable'))}
      <ChatMessagesStatusLine class="for-loading" icon="spinner" animation="spin"><a href="{route.baseUrl}" target="_self">{l('Loading...')}</a></ChatMessagesStatusLine>
    {/if}
  {:else}
    <ChatDialogAdd dialog="{dialog}"/>
  {/if}
</div>
