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

const now = new Time();
const user = getContext('user');

function ensureConnected(e) {
  e.preventDefault();
  user.events.ensureConnected();
}

function gotoDialogFromNotifications(e) {
  if (dialog.connection_id) return;
  const target = e.target.closest('.message');
  const message = dialog.messages[target.dataset.index];
  if (!message) return;
  e.preventDefault();
  const path = ['', 'chat', message.connection_id, message.dialog_id].map(encodeURIComponent).join('/');
  gotoUrl(path + '#' + message.ts.toISOString());
}

function senderIsOnline(message) {
  return dialog.participant(message.fromId) || message.fromId == connection.connection_id;
}

function toggleDetails(e) {
  const messageEl = e.target.closest('.message');
  user.embedMaker.toggleDetails(messageEl, dialog.messages[messageEl.dataset.index]);
}
</script>

{#if dialog.messages.length == 0}
  <h2>{l(dialog.dialog_id == 'notifications' ? 'No notifications.' : 'No messages.')}</h2>
{/if}

{#if dialog.messages.length > 40 && dialog.is('loading')}
  <ChatMessagesStatusLine class="for-loading" icon="spinner" animation="spin">{l('Loading...')}</ChatMessagesStatusLine>
{/if}

{#each dialog.messages as message, i}
  {#if i && i == dialog.messages.length - dialog.unread}
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

{#if connection.frozen}
  <div class="message is-type-error">
    <Icon name="cog" style="color:{connection.color}"/>
    <b class="message__ts" title="{now.toLocaleString()}">{now.getHM()}</b>
    <Link href="#activeMenu:settings" class="message__from" style="color:{connection.color}">Convos</Link>
    {#if connection.state == 'unreachable'}
      <div class="message__text" on:click="{ensureConnected}">
        {@html lmd('Trying to [reconnect](#reconnect)...')}
      </div>
    {:else}
      <div class="message__text">
        {@html lmd('Your connection %1 can be edited in [settings](%2).', connection.name, '#activeMenu:settings')}
      </div>
    {/if}
  </div>
{/if}

{#if user.wantNotifications === null}
  <div class="message is-type-error">
    <Icon name="cog" style="color:{connection.color}"/>
    <b class="message__ts" title="{now.toLocaleString()}">{now.getHM()}</b>
    <Link href="/settings" class="message__from" style="color:{connection.color}">Convos</Link>
    <div class="message__text">{@html lmd('Please go to [settings](/settings) to enable notifications.')}</div>
  </div>
{/if}

{#if dialog.is('loading')}
  <ChatMessagesStatusLine class="for-loading" icon="spinner" animation="spin">{l('Loading...')}</ChatMessagesStatusLine>
{/if}
