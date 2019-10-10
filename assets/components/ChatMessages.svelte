<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {getContext} from 'svelte';
import {l} from '../js/i18n';

export let connection = {};
export let dialog = {};

const user = getContext('user');
</script>

{#each dialog.messages as message, i}
  {#if message.endOfHistory}
    <div class="message-status-line for-start-of-history"><span>{l('Start of history')}</span></div>
  {:else if message.dayChanged}
    <div class="message-status-line for-day-changed"><span>{message.ts.getHumanDate()}</span></div>
  {/if}

  {#if i && i == dialog.messages.length - dialog.unread}
    <div class="message-status-line for-last-read"><span>{l('New messages')}</span></div>
  {/if}

  <div class="message is-type-{message.type || 'notice'}"
    class:is-sent-by-you="{message.from == connection.nick}"
    class:is-hightlighted="{message.highlight}"
    class:has-not-same-from="{!message.isSameSender && !message.dayChanged}"
    class:has-same-from="{message.isSameSender && !message.dayChanged}"
    data-index="{i}">

    <Icon name="{message.from == connection.nick ? user.icon : 'random:' + message.from}" family="solid" style="color:{message.color}"/>
    <b class="message__ts" title="{message.ts.toLocaleString()}">{message.ts.toHuman()}</b>
    <Link className="message__from" href="/chat/{connection.connection_id}/{message.from}" style="color:{message.color}">{message.from}</Link>
    <div class="message__text">{@html message.markdown}</div>
  </div>
{/each}

{#if dialog.is('loading')}
  <div class="message-status-line for-loading"><span>{l('Loading...')}</span></div>
{/if}
