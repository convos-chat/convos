<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatMessages from '../components/ChatMessages.svelte';
import ConnectionSettings from '../components/ConnectionSettings.svelte';
import DialogSettings from '../components/DialogSettings.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import {activeMenu, currentUrl, gotoUrl} from '../store/router';
import {afterUpdate, getContext, onDestroy} from 'svelte';
import {debounce, modeClassNames, q} from '../js/util';
import {l, topicOrStatus} from '../js/i18n';

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
let pathParts = $currentUrl.pathParts;
let unsubscribe = [];

$: calculateDialog($user, $currentUrl);

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

function calculateDialog(user, currentUrl) {
  pathParts = currentUrl.pathParts;
  const c = user.findDialog({connection_id: pathParts[1]}) || {};
  if (c != connection) connection = c;

  const d = pathParts.length == 1 ? user.notifications : user.findDialog({connection_id: pathParts[1], dialog_id: pathParts[2]});
  if (!d) return (dialog = user.notifications);
  if (d == dialog && previousPath) return;
  if (unsubscribe) unsubscribe.forEach(cb => cb());
  if (previousPath && dialog.setLastRead) dialog.setLastRead();

  q(document, '.message__embed', embedEl => embedEl.remove());
  dialog = d;
  previousPath = currentUrl.path;
  unsubscribe = [];
  if (connection.subscribe) unsubscribe.push(connection.subscribe(c => { connection = c }));
  if (dialog != connection) unsubscribe.push(dialog.subscribe(d => { dialog = d }));

  dialog.load();
  settingsComponent = !dialog.connection_id ? null : dialog.dialog_id ? DialogSettings : ConnectionSettings;
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
    user.embedMaker.render((dialog.messages[target.dataset.index] || {}).embeds || [], target);
  });
}

function observeMessages() {
  observer = observer || new IntersectionObserver(observed, {rootMargin: '0px'});
  q(document, '.message', messageEl => observer.observe(messageEl));
}

const onScroll = debounce(e => {
  if (!messagesEl || !dialog.dialog_id) return;

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

{#if $activeMenu == 'settings'}
  <svelte:component this="{settingsComponent}" dialog="{dialog}"/>
{/if}

<ChatHeader>
  <h1>
    <a href="#activeMenu:{dialog.connection_id ? 'settings' : ''}">
      <Icon name="{dialog.connection_id ? 'sliders-h' : 'bell'}"/><span>{pathParts[2] || pathParts[1] || l('Notifications')}</span>
    </a>
  </h1>
  <small>{topicOrStatus(connection, dialog)}</small>
</ChatHeader>

<main class="main" bind:this="{messagesEl}" on:scroll="{onScroll}">
  <div class="messages-container" class:has-notifications="{pathParts.length == 1}" bind:offsetHeight="{messagesHeight}">
    {#if $user.is('loading') || (dialog.is('loading') && !dialog.messages.length)}
      <h2>{l('Loading...')}</h2>
    {:else if pathParts[1] && !connection.connection_id}
      <h2>{l('Connection does not exist.')}</h2>
      <p>{l('Do you want to create the connection "%1"?', pathParts[1])}</p>
      <p>
        <Link href="/add/connection?server={encodeURIComponent(pathParts[1])}&dialog={encodeURIComponent(pathParts[2])}" class="btn">{l('Yes')}</Link>
        <Link href="/chat" class="btn">{l('No')}</Link>
      </p>
    {:else if pathParts[2] && !dialog.connection_id}
      <h2>{l('You are not part of this conversation.')}</h2>
      <p>{l('Do you want to chat with "%1"?', pathParts[2])}</p>
      <p>
        <a href="#add:{pathParts[2]}" on:click|preventDefault="{addDialog}" class="btn">{l('Yes')}</a>
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
  <div class="sidebar-right">
    <nav class="sidebar-right__nav">
      <h3>{l('Participants (%1)', dialog.participants.size)}</h3>
      {#each dialog.participants.toArray() as participant}
        <Link href="/chat/{dialog.connection_id}/{participant.id}" class="participant {modeClassNames(participant.mode)}">
          <Icon name="pick:{participant.id}" family="solid" style="color:{participant.color}"/>
          <span>{participant.nick}</span>
        </Link>
      {/each}
    <nav>
  </div>
{/if}
