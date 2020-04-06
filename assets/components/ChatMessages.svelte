<script>
import Button from './form/Button.svelte';
import ChatMessage from './ChatMessage.svelte';
import ChatMessagesStatusLine from './ChatMessagesStatusLine.svelte';
import Icon from './Icon.svelte';
import internalMessages from '../js/internalMessages';
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import {route} from '../store/Route';

export let connection;
export let dialog;
export let input;

const user = getContext('user');
const omnibus = user.omnibus;

$: messages = addMeta(internalMessages.mergeWithMessages($user, $connection, $dialog));
$: unreadFrom = $dialog.unread;

function addMeta(messages) {
  return messages.map((msg, i) => {
    msg.dayChanged
      = !dialog.messages.length ? false
      : i == 0 ? dialog.is('search')
      : msg.ts.getDate() != messages[i - 1].ts.getDate();

    return msg;
  });
}

function canToggleDetails(message) {
  return message.type == 'error' || message.type == 'notice';
}

function gotoDialogFromNotifications(e) {
  if (dialog.is('conversation')) return;
  const target = e.target.closest('.message');
  const message = messages[target.dataset.index];
  if (!message || !message.dialog_id) return;
  e.preventDefault();
  route.go(notififactionUrl(message)); // TODO
}

function isSameSender(i) {
  return i == 0 ? false : messages[i].fromId == messages[i - 1].fromId;
}

function notififactionUrl(message) {
  const url = ['', 'chat', message.connection_id, message.dialog_id].map(encodeURIComponent).join('/');
  return url + '#' + message.ts.toISOString();
}

function senderIsOnline(message) {
  return message.fromId == 'Convos' || message.fromId == dialog.connection_id || !dialog.dialog_id || dialog.findParticipant(message.fromId);
}

function toggleDetails(e) {
  const messageEl = e.target.closest('.message');
  user.embedMaker.toggleDetails(messageEl, messages[messageEl.dataset.index]);
}
</script>

{#if $dialog.messages.length == 0 && $dialog.is('notifications')}
  <h2>{l('No notifications.')}</h2>
{/if}

{#if messages.length > 40 && $dialog.is('loading')}
  <ChatMessagesStatusLine class="for-loading" icon="spinner" animation="spin">{l('Loading...')}</ChatMessagesStatusLine>
{/if}

{#each messages as message, i}
  {#if i && i == messages.length - unreadFrom}
    <ChatMessagesStatusLine class="for-last-read" icon="comments">{l('New messages')}</ChatMessagesStatusLine>
  {/if}

  {#if i == 0 && $dialog.endOfHistory}
    <ChatMessagesStatusLine class="for-start-of-history" icon="calendar-alt">{l('Started chatting on %1', message.ts.getHumanDate())}</ChatMessagesStatusLine>
  {:else if message.dayChanged}
    <ChatMessagesStatusLine class="for-day-changed" icon="calendar-alt">{message.ts.getHumanDate()}</ChatMessagesStatusLine>
  {/if}

  <div class="message is-type-{message.type}"
    class:is-not-present="{!senderIsOnline(message)}"
    class:is-sent-by-you="{message.from == $connection.nick}"
    class:is-highlighted="{message.highlight}"
    class:has-not-same-from="{!isSameSender(i) && !message.dayChanged}"
    class:has-same-from="{isSameSender(i) && !message.dayChanged}"
    on:click="{gotoDialogFromNotifications}"
    data-index="{i}">

    <Icon name="pick:{message.fromId}" color="{message.color}"/>
    <b class="message__ts" aria-labelledby="{message.id + '_ts'}">{message.ts.getHM()}</b>
    <div role="tooltip" id="{message.id + '_ts'}">{message.ts.toLocaleString()}</div>
    {#if $dialog.connection_id || !message.dialog_id}
      <a href="#input:{message.from}" on:click|preventDefault="{() => input && input.add(message.from)}" class="message__from" style="color:{message.color}" tabindex="-1">{message.from}</a>
    {:else}
      <a href="{notififactionUrl(message)}" class="message__from" style="color:{message.color}">{l('%1 in %2', message.from, message.dialog_id)}</a>
    {/if}
    <div class="message__text">
      {#if canToggleDetails(message)}
        <Icon name="{message.type == 'error' ? 'exclamation-circle' : 'info-circle'}" on:click="{toggleDetails}"/>
      {/if}
      {@html message.markdown}
    </div>
  </div>
{/each}

{#if $omnibus.wantNotifications === null}
  <ChatMessage>
    {l('Do you want to be notified when someone sends you a private message?')}
    <br>
    <Button type="button" icon="thumbs-up" on:click="{() => omnibus.requestPermissionToNotify()}">{l('Yes')}</Button>
    <Button type="button" icon="thumbs-down" on:click="{() => omnibus.requestPermissionToNotify(false)}">{l('No')}</Button>
  </ChatMessage>
{:else if typeof $omnibus.protocols.irc == 'undefined'}
  <ChatMessage>
    {l('Do you want %1 to handle "irc://" links?', l('Convos'))}
    <br>
    <Button type="button" icon="thumbs-up" on:click="{() => omnibus.registerProtocol('irc', true)}">{l('Yes')}</Button>
    <Button type="button" icon="thumbs-down" on:click="{() => omnibus.registerProtocol('irc', false)}">{l('No')}</Button>
  </ChatMessage>
{/if}

{#if ($connection.is && $connection.is('unreachable')) || !$dialog.is('success')}
  <ChatMessagesStatusLine class="for-loading" icon="spinner" animation="spin"><a href="{route.baseUrl}" target="_self">{l('Loading...')}</a></ChatMessagesStatusLine>
{/if}
