<script>
import ChatMessages from '../js/ChatMessages';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatMessagesContainer from '../components/ChatMessagesContainer.svelte';
import ChatMessagesStatusLine from '../components/ChatMessagesStatusLine.svelte';
import ChatParticipants from '../components/ChatParticipants.svelte';
import DragAndDrop from '../js/DragAndDrop';
import Icon from '../components/Icon.svelte';
import {afterUpdate, getContext, onDestroy, onMount} from 'svelte';
import {focusMainInputElements} from '../js/util';
import {l, topicOrStatus} from '../js/i18n';
import {q} from '../js/util';
import {route} from '../store/Route';

const chatMessages = new ChatMessages();
const dragAndDrop = new DragAndDrop();
const user = getContext('user');

// Elements
let chatInput;
let messagesEl;

// Variables for scrolling
let messagesHeight = 0;
let observer;

// Variables for calculating active connection and dialog
let connection = {};
let dialog = user.notifications;
let unsubscribe = {};

chatMessages.attach({connection, dialog, user});

$: setDialogFromRoute($route);
$: setDialogFromUser($user);
$: dragAndDrop.attach(document, messagesEl, chatInput && chatInput.getUploadEl());
$: messages = chatMessages.merge($dialog.messages);

afterUpdate(() => {
  observer = observer || new IntersectionObserver(messageElObserved, {rootMargin: '0px'});
  q(document, '.message', messageEl => {
    if (!messageEl.classList.contains('is-observed')) observer.observe(messageEl);
    messageEl.classList.add('is-observed');
  });
});

onMount(() => focusMainInputElements('chat_input'));
onDestroy(onClose);

function toggleDetails(e) {
  const messageEl = e.target.closest('.message');
  user.embedMaker.toggleDetails(messageEl, messages[messageEl.dataset.index]);
}

function setDialogFromRoute(route) {
  const [connection_id, dialog_id] = ['connection_id', 'dialog_id'].map(k => route.param(k));
  if (dialog.connection_id == connection_id && dialog.dialog_id == dialog_id) return;
  if (user.omnibus.debug > 1) console.log('[setDialogFromRoute]', JSON.stringify([connection_id, dialog_id]));
  user.setActiveDialog({connection_id, dialog_id}); // Triggers setDialogFromUser()
}

function setDialogFromUser(user) {
  if (user.activeDialog == chatMessages.dialog) return;
  if (unsubscribe.dialog) onClose();
  if (user.omnibus.debug > 1) console.log('[setDialogFromUser]', user.activeDialog.name);

  dialog = user.activeDialog;
  connection = user.findDialog({connection_id: dialog.connection_id}) || {};
  chatMessages.attach({connection, dialog, user});

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
</script>

<ChatHeader>
  <h1>
    <a href="#activeMenu:{dialog.connection_id ? 'settings' : 'nav'}" tabindex="-1">
      <Icon name="sliders-h"/><span>{l(dialog.name)}</span>
    </a>
  </h1>
  <a href="#activeMenu:{dialog.connection_id ? 'settings' : 'nav'}" class="chat-header__topic">{topicOrStatus(connection, dialog)}</a>
</ChatHeader>

<main class="main for-chat" bind:this="{messagesEl}">
  <ChatMessagesContainer dialog="{dialog}" bind:messagesHeight="{messagesHeight}">
    {#each messages as message, i}
      {#if chatMessages.dayChanged(messages, i)}
        <ChatMessagesStatusLine class="for-day-changed" icon="calendar-alt">{message.ts.getHumanDate()}</ChatMessagesStatusLine>
      {/if}

      {#if i && i == messages.length - $dialog.unread}
        <ChatMessagesStatusLine class="for-last-read" icon="comments">{l('New messages')}</ChatMessagesStatusLine>
      {/if}

      <div class="{chatMessages.classNames(messages, i)}" data-index="{i}" data-ts="{message.ts.toISOString()}">
        <Icon name="pick:{message.fromId}" color="{message.color}"/>
        <b class="message__ts" aria-labelledby="{message.id + '_ts'}">{message.ts.getHM()}</b>
        <div role="tooltip" id="{message.id + '_ts'}">{message.ts.toLocaleString()}</div>
        <a href="#input:{message.from}" on:click|preventDefault="{() => chatInput.add(message.from)}" class="message__from" style="color:{message.color}" tabindex="-1">{message.from}</a>
        <div class="message__text">
          {#if chatMessages.canToggleDetails(message)}
            <Icon name="{message.type == 'error' ? 'exclamation-circle' : 'info-circle'}" on:click="{toggleDetails}"/>
          {/if}
          {@html message.markdown}
        </div>
      </div>
    {/each}
  </ChatMessagesContainer>
</main>

<ChatInput dialog="{dialog}" bind:this="{chatInput}"/>
<ChatParticipants dialog="{dialog}"/>
