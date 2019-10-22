<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import Time from '../js/Time';
import {getContext} from 'svelte';
import {l, lmd, topicOrStatus} from '../js/i18n';
import {gotoUrl} from '../store/router';

export let connection;
export let dialog;
export let input;

const now = new Time();
const user = getContext('user');

function ensureConnected(e) {
  e.preventDefault();
  user.events.ensureConnected();
}

function gotoDialog(e) {
  if (dialog.connection_id) return;
  const target = e.target.closest('.message');
  const message = dialog.messages[target.dataset.index];
  if (!message) return;
  e.preventDefault();
  const path = ['', 'chat', message.connection_id, message.dialog_id].map(encodeURIComponent).join('/');
  gotoUrl(path + '#' + message.ts.toISOString());
}
</script>

{#if !dialog.messages.length}
  <h2>{l(dialog.dialog_id == 'notifications' ? 'No notifications.' : 'No messages.')}</h2>
{/if}

{#each dialog.messages as message, i}
  {#if i && i == dialog.messages.length - dialog.unread}
    <div class="message-status-line for-last-read"><span>{l('New messages')}</span></div>
  {/if}

  {#if message.endOfHistory}
    <div class="message-status-line for-start-of-history"><span>{l('Start of history')}</span></div>
  {:else if message.dayChanged}
    <div class="message-status-line for-day-changed"><span>{message.ts.getHumanDate()}</span></div>
  {/if}

  <div class="message is-type-{message.type || 'notice'}"
    class:is-sent-by-you="{message.from == connection.nick}"
    class:is-hightlighted="{message.highlight}"
    class:has-not-same-from="{!message.isSameSender && !message.dayChanged}"
    class:has-same-from="{message.isSameSender && !message.dayChanged}"
    on:click="{gotoDialog}"
    data-index="{i}">

    <Icon name="{message.from == connection.nick ? user.icon : 'random:' + message.from}" family="solid" style="color:{message.color}"/>
    <b class="message__ts" title="{message.ts.toLocaleString()}">{message.ts.toHuman()}</b>
    {#if dialog.connection_id}
      <a href="#input:{message.from}" on:click|preventDefault="{() => input.add(message.from)}" class="message__from" style="color:{message.color}">{message.from}</a>
    {:else}
      <a href="#see" class="message__from" style="color:{message.color}">{l('%1 in %2', message.from, message.dialog_id)}</a>
    {/if}
    <div class="message__text">{@html message.markdown}</div>
  </div>
{/each}

{#if connection.frozen || dialog.frozen}
  <div class="message-status-line for-connection-status"><span>{topicOrStatus(connection, dialog).replace(/\.$/, '')}</span></div>
{/if}

{#if connection.frozen}
  <div class="message is-type-notice is-hightlighted has-not-same-from">
    <Icon name="cog" style="color:{connection.color}"/>
    <b class="message__ts" title="{now.toLocaleString()}">{now.toHuman()}</b>
    <Link href="#activeMenu:settings" class="message__from" style="color:{connection.color}">{connection.name}</Link>
    {#if connection.state == 'unreachable'}
      <div class="message__text" on:click="{ensureConnected}">
        {@html lmd('You will be [reconnected](#reconnect) soon...')}
      </div>
    {:else}
      <div class="message__text">
        {@html lmd('Your connection %1 can be edited in [settings](%2).', connection.name, '#activeMenu:settings')}
      </div>
    {/if}
  </div>
{/if}

{#if dialog.is('loading')}
  <div class="message-status-line for-loading"><span>{l('Loading...')}</span></div>
{/if}
