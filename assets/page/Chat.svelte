<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatMessages from '../components/ChatMessages.svelte';
import ConnectionSettings from '../components/ConnectionSettings.svelte';
import DialogParticipants from '../components/DialogParticipants.svelte';
import DialogSettings from '../components/DialogSettings.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import {activeMenu, gotoUrl, pathParts, currentUrl} from '../store/router';
import {afterUpdate, getContext, onDestroy, onMount, tick} from 'svelte';
import {debounce, q} from '../js/util';
import {l, topicOrStatus} from '../js/i18n';

const embedMaker = getContext('embedMaker');
const user = getContext('user');

// Elements
let chatInput;
let messagesEl;
let settingsComponent = null;

// Variables for scrolling
let containerHeight = 0;
let messagesHeight = 0;
let messagesHeightLast = 0;
let observer;
let scrollPos = 'bottom';

// Variables for calculating active connection and dialog
let connection = {};
let dialog = user.notifications;
let previousPath = '';
let unsubscribe = [];

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
  unsubscribe.forEach(cb => cb());
});

function addDialog(e) {
  if (connection.connection_id) connection.addDialog(e.target.closest('a').href.replace(/.*#add:/, ''));
}

function calculateDialog(user, pathParts) {
  const c = user.findDialog({connection_id: pathParts[1]}) || {};
  if (c != connection) connection = c;

  const d = pathParts.length == 1 ? user.notifications : user.findDialog({connection_id: pathParts[1], dialog_id: $pathParts[2]});
  if (!d) return (dialog = user.notifications);
  if (d == dialog && previousPath) return;
  if (unsubscribe) unsubscribe.forEach(cb => cb());
  if (previousPath && dialog.setLastRead) dialog.setLastRead();

  dialog = d;
  previousPath = pathParts.join('/');
  unsubscribe = [];
  if (connection.subscribe) unsubscribe.push(connection.subscribe(c => { connection = c }));
  if (dialog != connection) unsubscribe.push(dialog.subscribe(d => { dialog = d }));

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

function showSettings() {
  $activeMenu = $activeMenu == 'settings' ? '' : 'settings';
  gotoUrl(dialog.connection_id ? dialog.path + '#settings' : '/settings');
}
</script>

<svelte:window bind:innerHeight="{containerHeight}"/>

<SidebarChat/>

<svelte:component this="{settingsComponent}" dialog="{dialog}"/>

<ChatHeader>
  <h1 class="is-link" on:click="{showSettings}">{$pathParts[2] || $pathParts[1] || l('Notifications')}</h1>
  <small>{topicOrStatus(connection, dialog)}</small>
</ChatHeader>

<main class="main messages-wrapper" bind:this="{messagesEl}" on:scroll="{onScroll}">
  <div class="messages-container" bind:offsetHeight="{messagesHeight}">
    {#if $user.is('loading') || (dialog.is('loading') && !dialog.messages.length)}
      <h2>{l('Loading...')}</h2>
    {:else if $pathParts[1] && !connection.connection_id}
      <h2>{l('Connection does not exist.')}</h2>
      <p>{l('Do you want to create the connection "%1"?', $pathParts[1])}</p>
      <p>
        <Link href="/add/connection?server={encodeURIComponent($pathParts[1])}&dialog={encodeURIComponent($pathParts[2])}" class="btn">{l('Yes')}</Link>
        <Link href="/chat" class="btn">{l('No')}</Link>
      </p>
    {:else if $pathParts[2] && !dialog.connection_id}
      <h2>{l('You are not part of this conversation.')}</h2>
      <p>{l('Do you want to chat with "%1"?', $pathParts[2])}</p>
      <p>
        <a href="#add:{$pathParts[2]}" on:click|preventDefault="{addDialog}" class="btn">{l('Yes')}</a>
        <Link href="/chat" class="btn">{l('No')}</Link>
      </p>
    {:else}
      <ChatMessages connection="{connection}" dialog="{dialog}" input="{chatInput}"/>
    {/if}
  </div>
</main>

{#if dialog.connection_id}
  <ChatInput dialog="{dialog}" bind:this="{chatInput}"/>
{/if}

{#if dialog.participants.size}
  <div class="sidebar-participants-wrapper">
    <div class="sidebar__nav">
      <h3>{l('Participants (%1)', dialog.participants.size)}</h3>
      <DialogParticipants dialog="{dialog}"/>
    </div>
  </div>
{/if}
