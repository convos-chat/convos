<script>
import Button from '../components/form/Button.svelte';
import ChatDialogAdd from '../components/ChatDialogAdd.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatMessages from '../components/ChatMessages.svelte';
import DragAndDrop from '../js/DragAndDrop';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import TextField from '../components/form/TextField.svelte';
import {afterUpdate, getContext, onDestroy} from 'svelte';
import {closestEl, debounce, modeClassNames, q} from '../js/util';
import {l, topicOrStatus} from '../js/i18n';
import {route} from '../store/Route';

const dragAndDrop = new DragAndDrop();
const user = getContext('user');

// Elements
let chatInput;
let messagesEl;

// Variables for scrolling
let [messagesHeight, messagesHeightLast] = [0, 0];
let observer;
let scrollPos = 'bottom';

// Variables for calculating active connection and dialog
let connection = {};
let dialog = user.notifications;
let previousDialog = null;
let unsubscribe = {};

$: setDialogFromRoute($route);
$: setDialogFromUser($user);
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

function setDialogFromRoute(route) {
  const [connection_id, dialog_id] = ['connection_id', 'dialog_id'].map(k => route.param(k));
  if (dialog.connection_id == connection_id && dialog.dialog_id == dialog_id) return;
  user.setActiveDialog({connection_id, dialog_id}); // Triggers setDialogFromUser()
}

function setDialogFromUser(user) {
  if (user.activeDialog == previousDialog) return;
  if (unsubscribe.dialog) onClose();

  dialog = user.activeDialog;
  connection = user.findDialog({connection_id: dialog.connection_id}) || {};
  messagesHeightLast = 0;
  previousDialog = dialog;
  scrollPos = 'bottom';

  q(document, '.message__embed', embedEl => embedEl.remove());
  dialog.load({before: 'maybe'});
  route.update({title: dialog.title});
  unsubscribe.dialog = dialog.subscribe(d => { dialog = d });
}

function messageElObserved(entries, observer) {
  entries.forEach(e => {
    if (!e.isIntersecting) return;
    const message = dialog.messages[e.target.dataset.index] || {};
    if (message.embeds) user.embedMaker.render(e.target, message.embeds);
  });
}

function onClose() {
  if (dialog.setLastRead) dialog.setLastRead();
  if (unsubscribe.dialog) unsubscribe.dialog();
  dragAndDrop.detach();
}

const onScroll = debounce(e => {
  if (!messagesEl) return;

  const offsetHeight = messagesEl.offsetHeight;
  const scrollTop = messagesEl.scrollTop;

  scrollPos = offsetHeight > messagesHeight || scrollTop + 20 > messagesHeight - offsetHeight ? 'bottom'
            : scrollTop < 100 ? 'top'
            : 'middle';

  if (scrollPos == 'top' && !dialog.is('loading')) {
    if (dialog.messages.length) dialog.load({before: 0});
    messagesHeightLast = messagesHeight;
  }
}, 20);
</script>

<ChatHeader>
  <h1>
    <a href="#activeMenu:{dialog.connection_id ? 'settings' : 'nav'}" tabindex="-1">
      <Icon name="{dialog.connection_id ? 'sliders-h' : 'bell'}"/><span>{l(dialog.name)}</span>
    </a>
  </h1>
  <a href="#activeMenu:{dialog.connection_id ? 'settings' : 'nav'}" class="chat-header__topic">{topicOrStatus(connection, dialog)}</a>
</ChatHeader>

<main class="main" bind:this="{messagesEl}" on:scroll="{onScroll}">
  <div class="messages-container" class:has-notifications="{dialog.is('notifications')}" bind:offsetHeight="{messagesHeight}">
    {#if !dialog.connection_id || user.findDialog(dialog)}
      <ChatMessages connection="{connection}" dialog="{dialog}" input="{chatInput}"/>
    {:else}
      <ChatDialogAdd dialog="{dialog}"/>
    {/if}
  </div>
</main>

{#if !dialog.is('notifications')}
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
