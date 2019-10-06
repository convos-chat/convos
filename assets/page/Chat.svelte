<script>
import {afterUpdate, getContext, onDestroy, onMount, tick} from 'svelte';
import {debounce, q} from '../js/util';
import {l} from '../js/i18n';
import {pathParts, currentUrl} from '../store/router';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ConnectionSettings from '../components/ConnectionSettings.svelte';
import DialogSettings from '../components/DialogSettings.svelte';
import DialogSubject from '../components/DialogSubject.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import SidebarChat from '../components/SidebarChat.svelte';

const embedMaker = getContext('embedMaker');
const user = getContext('user');

// Elements
let messagesEl;
let settingsComponent = null;

// Variables for scrolling
let containerHeight = 0;
let messagesHeight = 0;
let messagesHeightLast = 0;
let observer;
let scrollingClass = 'has-no-scrolling';
let scrollPos = 'bottom';

// Variables for calculating active connection and dialog
let connection = {};
let dialog = user.notifications;
let previousPath = '';
let unsubscribeDialog;

$: calculateDialog($user, $pathParts);
$: calculateSettingsComponent($currentUrl);

onMount(() => {
  // Clean up any embeds added from a previous chat
  q(document, '.message__embed', embedEl => embedEl.remove());
});

afterUpdate(() => {
  observeMessages();
  keepScrollPosition();
});

onDestroy(() =>  {
  if (unsubscribeDialog) unsubscribeDialog();
});

function addDialog(e) {
  if (connection.connection_id) connection.addDialog(e.target.closest('a').href.replace(/.*#add:/, ''));
}

function calculateDialog(user, pathParts) {
  if (previousPath == pathParts.join('/')) return;

  const d = pathParts.length == 1 ? user.notifications : user.findDialog({connection_id: pathParts[1], dialog_id: $pathParts[2]});
  if (!d) return;
  if (d == dialog && previousPath) return;
  if (unsubscribeDialog) unsubscribeDialog();
  if (previousPath && dialog.setLastRead) dialog.setLastRead();

  connection = user.findDialog({connection_id: pathParts[1]}) || {};
  dialog = d;
  previousPath = pathParts.join('/');
  unsubscribeDialog = dialog.subscribe(d => { dialog = d });
  dialog.load();
  calculateSettingsComponent($currentUrl);
}

function calculateSettingsComponent(currentUrl) {
  if (currentUrl.hash == '#settings' && dialog.connection_id) {
    settingsComponent = dialog.dialog_id ? DialogSettings : ConnectionSettings;
  }
  else {
    settingsComponent = null;
  }
}

const calculateScrollingClass = debounce(hasScrolling => {
  scrollingClass = hasScrolling ? 'has-scrolling' : 'has-no-scrolling';
}, 100);

function keepScrollPosition() {
  if (scrollPos == 'bottom') {
    messagesEl.scrollTop = messagesHeight;
  }
  else if (messagesHeightLast && messagesHeightLast < messagesHeight) {
    messagesEl.scrollTop = messagesHeight - messagesHeightLast;
    messagesHeightLast = 0;
  }
}

function observed(entries, observer) {
  entries.forEach(({isIntersecting, target}) => {
    if (!isIntersecting) return;
    embedMaker.render((dialog.messages[target.dataset.index] || {}).embeds || [], target);
  });
}

function observeMessages() {
  observer = observer || new IntersectionObserver(observed, {rootMargin: '0px'});
  q(document, '.message', messageEl => observer.observe(messageEl));
}

const onScroll = debounce(e => {
  if (!dialog.dialog_id) return;

  const offsetHeight = messagesEl.offsetHeight;
  const scrollTop = messagesEl.scrollTop;

  scrollPos = offsetHeight > messagesHeight || scrollTop + 20 > messagesHeight - offsetHeight ? 'bottom'
            : scrollTop < 100 ? 'top'
            : 'middle';

  if (scrollPos == 'top' && !dialog.is('loading')) {
    if (dialog.messages.length && !dialog.messages[0].endOfHistory) dialog.loadHistoric();
    messagesHeightLast = messagesHeight;
  }
}, 20);
</script>

<svelte:window bind:innerHeight="{containerHeight}"/>

<SidebarChat/>

<svelte:component this="{settingsComponent}" dialog="{dialog}"/>

<div class="main messages-wrapper {scrollingClass}" bind:this="{messagesEl}" on:scroll="{onScroll}">
  <main class="messages-container" bind:offsetHeight="{messagesHeight}">
    <ChatHeader>
      {#if $pathParts[1]}
        <h1>{$pathParts[2] || $pathParts[1]}</h1>
        <small><DialogSubject dialog="{dialog}"/></small>
      {:else}
        <h1>{l('Notifications')}</h1>
      {/if}
    </ChatHeader>

    {#if dialog.messages.length == 0}
      {#if !$pathParts[1]}
        <h2>{l('No notifications.')}</h2>
      {:else if $pathParts[1] == dialog.connection_id}
        <h2>{l(dialog.is('loading') ? 'Loading messages...' : 'No messages.')}</h2>
        <p>{dialog.frozen}</p>
      {/if}
    {/if}

    {#if $pathParts[2] && !dialog.dialog_id}
      <h2>{l('You are not part of this conversation.')}</h2>
      <p>Do you want to add the conversation?</p>
      <p>
        <a href="#add:{$pathParts[2]}" on:click="{addDialog}" class="btn">Yes</a>
        <Link href="/chat" className="btn">{l('No')}</Link>
      </p>
    {:else if $pathParts[1] && !connection.connection_id}
      <h2>{l('Connection does not exist.')}</h2>
      <p>{l('Do you want to make a new connection?')}</p>
      <p>
        <Link href="/add/connection?server={encodeURIComponent($pathParts[1])}" className="btn">{l('Yes')}</Link>
        <Link href="/chat" className="btn">{l('No')}</Link>
      </p>
    {/if}

    {#if dialog.is('loading')}
      <div class="message-status-line for-loading"><span>{l('Loading messages...')}</span></div>
    {/if}

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
        <Link className="message__from" href="/chat/{$pathParts[1]}/{message.from}" style="color:{message.color}">{message.from}</Link>
        <div class="message__text">{@html message.markdown}</div>
      </div>
    {/each}

    {#if dialog.connection_id}
      <ChatInput dialog="{dialog}"/>
    {/if}
  </main>
</div>
