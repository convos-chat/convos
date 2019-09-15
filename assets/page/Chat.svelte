<script>
import {debounce, timer} from '../js/util';
import {getContext, tick} from 'svelte';
import {gotoUrl, pathParts, currentUrl} from '../store/router';
import {l} from '../js/i18n';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ConnectionSettings from '../components/ConnectionSettings.svelte';
import DialogSettings from '../components/DialogSettings.svelte';
import DialogSubject from '../components/DialogSubject.svelte';
import Link from '../components/Link.svelte';
import SidebarChat from '../components/SidebarChat.svelte';

const user = getContext('user');
const w = window;

let height = 0;
let lastHeight = 0;
let scrollPos = 'bottom';

const onScroll = debounce(e => {
  const windowH = w.innerHeight;
  const scrollY = w.scrollY;
  const last = scrollPos;

  scrollPos = windowH > height || scrollY + 20 > height - windowH ? 'bottom'
            : scrollY < 100 ? 'top'
            : 'middle';

  if (scrollPos == last || !dialog.dialog_id) return;

  if (scrollPos == 'top' && !isLoading) {
    lastHeight = height;
    dialog.loadHistoric();
  }
}, 20);

$: dialog = $user.findDialog({connection_id: $pathParts[1], dialog_id: $pathParts[2]}) || user.notifications;
$: isLoading = dialog.op && dialog.op.is('loading') || false;
$: dialog.load();
$: fallbackSubject = dialog.frozen || ($pathParts[2] ? l('Private conversation.') : l('Server messages.'));
$: messages = $dialog.messages;
$: settingsComponent = $currentUrl.hash != '#settings' ? null : dialog.dialog_id ? DialogSettings : ConnectionSettings;

$: if (scrollPos == 'bottom') w.scrollTo(0, height);

$: if (lastHeight && lastHeight < height) {
  w.scrollTo(0, height - lastHeight);
  lastHeight = 0;
}
</script>

<svelte:window on:scroll="{onScroll}"/>

<SidebarChat/>

<svelte:component dialog="{dialog}" this="{settingsComponent}"/>

<main class="main messages-container" bind:offsetHeight="{height}">
  <ChatHeader>
    {#if $pathParts[1]}
      <h1>{$pathParts[2] || $pathParts[1]}</h1>
      <small><DialogSubject dialog="{dialog}"/></small>
    {:else}
      <h1>
        {l('Notifications')}
        <a href="#clear:notifications" on:click|preventDefault="{e => user.readNotifications.perform()}">
          ({dialog.unread})
        </a>
      </h1>
    {/if}
  </ChatHeader>

  {#if messages.length == 0}
    {#if !$pathParts[1]}
      <h2>{l('No notifications.')}</h2>
    {:else if $pathParts[1] == dialog.connection_id}
      <h2>{l(isLoading ? 'Loading messages...' : 'No messages.')}</h2>
      <p>{dialog.frozen}</p>
    {:else if $pathParts[2] && !dialog.dialog_id}
      <h2>{l('You are not part of this conversation.')}</h2>
      <p>Do you want to add the conversation?</p>
      <p>
        <Link href="/add/conversation?connection_id={encodeURIComponent($pathParts[1])}&dialog_id={encodeURIComponent($pathParts[2])}" className="btn">{l('Yes')}</Link>
        <Link href="/chat" className="btn">{l('No')}</Link>
      </p>
    {:else if $pathParts[1] && !dialog.connection_id}
      <h2>{l('Connection does not exist.')}</h2>
      <p>{l('Do you want to make a new connection?')}</p>
      <p>
        <Link href="/add/connection?server={encodeURIComponent($pathParts[1])}" className="btn">{l('Yes')}</Link>
        <Link href="/chat" className="btn">{l('No')}</Link>
      </p>
    {/if}
  {/if}

  {#if isLoading && scrollPos == 'top'}
    <div class="status-line for-loading"><span>{l('Loading messages...')}</span></div>
  {/if}

  {#each messages as message, i}
    {#if message.endOfHistory}
      <div class="status-line for-end-of-history"><span>{l('End of history')}</span></div>
    {:else if message.dayChanged}
      <div class="status-line for-day-changed"><span>{l('Day changed')}</span></div>
    {/if}

    <div class="message is-type-{message.type || 'notice'}"
      class:is-hightlighted="{message.highlight}"
      class:is-same="{message.isSameSender && !message.dayChanged}">
      <b class="ts" title="{message.dt.toLocaleString()}">{message.dt.toHuman()}</b>
      <Link className="message_from" href="/chat/{$pathParts[1]}/{message.from}">{message.from}</Link>
      <div class="message_text">{@html message.markdown}</div>
    </div>
  {/each}

  {#if isLoading && scrollPos != 'top'}
    <div class="status-line for-loading"><span>{l('Loading messages...')}</span></div>
  {/if}
</main>

{#if dialog.connection_id}
<ChatInput dialog="{dialog}"/>
{/if}
