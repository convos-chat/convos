<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatMessages from '../components/ChatMessages.svelte';
import ConnectionSettings from '../components/ConnectionSettings.svelte';
import DialogSettings from '../components/DialogSettings.svelte';
import DragAndDrop from '../js/DragAndDrop';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {activeMenu, container, currentUrl} from '../store/router';
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
let dragAndDrop = new DragAndDrop();
let previousPath = '';
let pathParts = $currentUrl.pathParts;
let unsubscribe = [];

$: calculateDialog($user, $currentUrl);
$: dragAndDrop.attach(document, messagesEl, chatInput && chatInput.getUploadEl());

afterUpdate(() => {
  // Load embeds when message gets into viewport
  observer = observer || new IntersectionObserver(messageElObserved, {rootMargin: '0px'});
  q(document, '.message', messageEl => {
    if (!messageEl.classList.contains('is-observed')) observer.observe(messageEl);
    messageEl.classList.add('is-observed');
  });

  // Keep the scroll position
  if (scrollPos == 'bottom') {
    messagesEl.scrollTop = messagesHeight;
  }
  else if (messagesHeightLast && messagesHeightLast < messagesHeight) {
    messagesEl.scrollTop = messagesHeight - messagesHeightLast;
    if (scrollPos != 'top') messagesHeightLast = 0;
  }
});

onDestroy(onClose);

function addDialog(e) {
  if (connection.connection_id) connection.addDialog(e.target.closest('a').href.replace(/.*#add:/, ''));
}

function calculateDialog($user, $currentUrl) {
  pathParts = $currentUrl.pathParts;
  const c = $user.findDialog({connection_id: pathParts[1]}) || {};
  if (c != connection) registerUrlHandler(connection = c);

  const d = pathParts.length == 1 ? $user.notifications : $user.findDialog({connection_id: pathParts[1], dialog_id: pathParts[2]});
  if (!d) return (dialog = $user.notifications);
  if (d == dialog && previousPath) return;
  if (previousPath) onClose();

  q(document, '.message__embed', embedEl => embedEl.remove());

  dialog = d;
  messagesHeightLast = 0;
  previousPath = $currentUrl.path;
  scrollPos = 'bottom';
  settingsComponent = !dialog.connection_id ? null : dialog.dialog_id ? DialogSettings : ConnectionSettings;

  unsubscribe = [];
  if (connection.subscribe) unsubscribe.push(connection.subscribe(c => { connection = c }));
  if (dialog.subscribe) unsubscribe.push(dialog.subscribe(d => { dialog = d }));

  if (!dialog.connection_id) {
    dialog.load({});
  }
  else if (dialog.is('pending')) {
    dialog.load({before: dialog.messages[0]});
  }
}

function messageElObserved(entries, observer) {
  entries.forEach(e => {
    if (!e.isIntersecting) return;
    const message = dialog.messages[e.target.dataset.index] || {};
    if (message.embeds) user.embedMaker.render(e.target, message.embeds);
  });
}

function onClose() {
  if (dialog && dialog.setLastRead) dialog.setLastRead();
  dragAndDrop.detach();
  unsubscribe.forEach(cb => cb());
}

const onScroll = debounce(e => {
  if (!messagesEl || !dialog.connection_id) return;

  const offsetHeight = messagesEl.offsetHeight;
  const scrollTop = messagesEl.scrollTop;

  scrollPos = offsetHeight > messagesHeight || scrollTop + 20 > messagesHeight - offsetHeight ? 'bottom'
            : scrollTop < 100 ? 'top'
            : 'middle';

  if (scrollPos == 'top' && !dialog.is('loading')) {
    if (dialog.messages.length) dialog.load({before: dialog.messages[0]});
    messagesHeightLast = messagesHeight;
  }
}, 20);

function registerUrlHandler(connection) {
  if (!connection.url) return;
  const protocol = connection.url.protocol.replace(/:$/, '');
  if (navigator.registerProtocolHandler) navigator.registerProtocolHandler(protocol, currentUrl.base + '/register?uri=%s', 'Convos ' + protocol + ' handler');
}
</script>

<svelte:window bind:innerHeight="{containerHeight}"/>

{#if $activeMenu == 'settings'}
  <svelte:component this="{settingsComponent}" dialog="{dialog}" transition="{{duration: 250, x: $container.wideScreen ? 0 : $container.width}}"/>
{/if}

<ChatHeader>
  <h1>
    <a href="#activeMenu:{dialog.connection_id ? 'settings' : ''}">
      <Icon name="{dialog.connection_id ? 'sliders-h' : 'bell'}"/><span>{pathParts[2] || pathParts[1] || l('Notifications')}</span>
    </a>
  </h1>
  <i class="chat-header__topic">{topicOrStatus(connection, dialog)}</i>
</ChatHeader>

<main class="main" bind:this="{messagesEl}" on:scroll="{onScroll}">
  <div class="messages-container" class:has-notifications="{pathParts.length == 1}" bind:offsetHeight="{messagesHeight}">
    {#if pathParts[1] && !connection.connection_id}
      <h2>{l('Connection does not exist.')}</h2>
      <p>{l('Do you want to create the connection "%1"?', pathParts[1])}</p>
      <p>
        <Link href="/settings/connection?server={encodeURIComponent(pathParts[1])}&dialog={encodeURIComponent(pathParts[2])}" class="btn">{l('Yes')}</Link>
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

{#if dialog.participants().length}
  <div class="sidebar-right">
    <nav class="sidebar-right__nav">
      <h3>{l('Participants (%1)', dialog.participants().length)}</h3>
      {#each dialog.participants() as participant}
        <Link href="/chat/{dialog.connection_id}/{participant.id}" class="participant {modeClassNames(participant.modes)}">
          <Icon name="pick:{participant.id}" family="solid" color="{participant.color}"/>
          <span>{participant.nick}</span>
        </Link>
      {/each}
    <nav>
  </div>
{/if}
