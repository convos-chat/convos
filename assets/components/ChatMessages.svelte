<script>
import ChatMessagesStatusLine from './ChatMessagesStatusLine.svelte';
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import Time from '../js/Time';
import {ensureChildNode} from '../js/util';
import {getContext} from 'svelte';
import {gotoUrl} from '../store/router';
import {l, lmd, topicOrStatus} from '../js/i18n';
import {showEl} from '../js/util';

export let connection;
export let dialog;
export let input;

const user = getContext('user');

$: messages = calculateMessages(dialog);

function calculateMessages(dialog) {
  const messages = dialog.messages.slice(0);

  if (connection.frozen) {
    const unreachable = connection.is('unreachable');
    messages.push(convosMessage({
      message: unreachable ? 'Trying to [reconnect](%1)...' : 'Your connection %1 can be edited in [settings](%2).',
      vars: unreachable ? ['#call:user:ensureConnected'] : [connection.name, '#activeMenu:settings'],
    }));
  }

  if (user.wantNotifications === null) {
    messages.push(convosMessage({
      message: 'Please go to [settings](%1) to enable notifications.',
      vars: ['/settings'],
    }));
  }

  return messages;
}

function convosMessage(message) {
  return {
    color: connection.color,
    from: 'Convos',
    markdown: lmd(message.message, ...message.vars),
    ts: new Time(),
    type: 'error',
    ...message,
  };
}

function gotoDialogFromNotifications(e) {
  if (dialog.connection_id) return;
  const target = e.target.closest('.message');
  const message = messages[target.dataset.index];
  if (!message) return;
  e.preventDefault();
  const path = ['', 'chat', message.connection_id, message.dialog_id].map(encodeURIComponent).join('/');
  gotoUrl(path + '#' + message.ts.toISOString());
}

function senderIsOnline(message) {
  return !message.dialog_id || dialog.participant(message.fromId);
}

function toggleDetails(e) {
  const messageEl = e.target.closest('.message');
  user.embedMaker.toggleDetails(messageEl, messages[messageEl.dataset.index]);
}
</script>

{#if messages.length == 0}
  <h2>{l(dialog.dialog_id == 'notifications' ? 'No notifications.' : 'No messages.')}</h2>
{/if}

{#if messages.length > 40 && dialog.is('loading')}
  <ChatMessagesStatusLine class="for-loading" icon="spinner" animation="spin">{l('Loading...')}</ChatMessagesStatusLine>
{/if}

{#each messages as message, i}
  {#if i && i == messages.length - dialog.unread}
    <ChatMessagesStatusLine class="for-last-read" icon="comments">{l('New messages')}</ChatMessagesStatusLine>
  {/if}

  {#if message.endOfHistory}
    <ChatMessagesStatusLine class="for-start-of-history" icon="calendar-alt">{l('Started chatting on %1', message.ts.getHumanDate())}</ChatMessagesStatusLine>
  {:else if message.dayChanged}
    <ChatMessagesStatusLine class="for-day-changed" icon="calendar-alt">{message.ts.getHumanDate()}</ChatMessagesStatusLine>
  {/if}

  <div class="message is-type-{message.type}"
    class:is-not-present="{!senderIsOnline(message)}"
    class:is-sent-by-you="{message.from == connection.nick}"
    class:is-highlighted="{message.highlight}"
    class:has-not-same-from="{!message.isSameSender && !message.dayChanged}"
    class:has-same-from="{message.isSameSender && !message.dayChanged}"
    on:click="{gotoDialogFromNotifications}"
    data-index="{i}">

    <Icon name="pick:{message.from}" style="color:{message.color}"/>
    <b class="message__ts" title="{message.ts.toLocaleString()}">{message.ts.getHM()}</b>
    {#if dialog.connection_id}
      <a href="#input:{message.from}" on:click|preventDefault="{() => input.add(message.from)}" class="message__from" style="color:{message.color}">{message.from}</a>
    {:else}
      <a href="#see" class="message__from" style="color:{message.color}">{l('%1 in %2', message.from, message.dialog_id)}</a>
    {/if}
    <div class="message__text">
      {#if message.type == 'error'}
        <Icon name="exclamation-circle" on:click="{toggleDetails}"/>
      {/if}
      {@html message.markdown}
    </div>
  </div>
{/each}

{#if connection.frozen || dialog.frozen}
  <ChatMessagesStatusLine class="for-connection-status" icon="exclamation-triangle">{topicOrStatus(connection, dialog).replace(/\.$/, '')}</ChatMessagesStatusLine>
{/if}

{#if dialog.is('loading')}
  <ChatMessagesStatusLine class="for-loading" icon="spinner" animation="spin">{l('Loading...')}</ChatMessagesStatusLine>
{/if}
