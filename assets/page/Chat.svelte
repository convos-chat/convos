<script>
import ChatMessages from '../js/ChatMessages';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatMessagesContainer from '../components/ChatMessagesContainer.svelte';
import ChatMessagesStatusLine from '../components/ChatMessagesStatusLine.svelte';
import ChatParticipants from '../components/ChatParticipants.svelte';
import DragAndDrop from '../js/DragAndDrop';
import Icon from '../components/Icon.svelte';
import Scrollspy from '../js/Scrollspy';
import Time from '../js/Time';
import {afterUpdate, getContext, onDestroy, onMount} from 'svelte';
import {focusMainInputElements, q} from '../js/util';
import {isISOTimeString} from '../js/Time';
import {l, topicOrStatus} from '../js/i18n';
import {route} from '../store/Route';

const before = {}; // Holds values so we can compare before/after changes
const chatMessages = new ChatMessages();
const dragAndDrop = new DragAndDrop();
const scrollspy = new Scrollspy();
const user = getContext('user');

// Elements
let chatInput;
let mainEl;

// Variables for scrolling
let messagesHeight = 0;

// Variables for calculating active connection and dialog
let connection = {};
let dialog = user.notifications;
let unsubscribe = {};

$: maybeReloadMessages($route);
$: setDialogFromRoute($route);
$: setDialogFromUser($user);
$: messages = chatMessages.merge($dialog.messages);
$: window.M = messages;
$: dragAndDrop.attach(document, mainEl, chatInput && chatInput.getUploadEl());

chatMessages.attach({connection, dialog, user});

onMount(() => {
  focusMainInputElements('chat_input');
});

afterUpdate(() => {

  // Remove already embedded elements when scrolling back in history
  const firstTs = messages.length && messages[0].ts.toISOString();
  if (firstTs && before.chatFirstTs != firstTs) q(document, '.message__embed', embedEl => embedEl.remove());
  before.chatFirstTs = firstTs;

  // Make sure we observe all message elements
  scrollspy.wrapper = mainEl;
  scrollspy.observe('.message');
  if (messagesHeight != before.chatMessagesHeight) scrollspy.keepPos(messagesHeight);
  before.chatMessagesHeight = messagesHeight;
  q(mainEl, '.message', el => el.classList[el.dataset.ts == $route.hash ? 'add' : 'remove']('has-focus'));
});

onDestroy(() => {
  if (dialog.setLastRead) dialog.setLastRead();
  Object.keys(unsubscribe).forEach(name => unsubscribe[name]());
  dragAndDrop.detach();
});

unsubscribe.observed = scrollspy.on('observed', entry => {
  if (!entry.isIntersecting) return;
  const message = dialog.messages[entry.target.dataset.index] || {};
  if (message.embeds) user.embedMaker.render(entry.target, message.embeds);
});

unsubscribe.scroll = scrollspy.on('scroll', entry => {
  if (!dialog.messages.length || dialog.is('loading')) return;

  if (scrollspy.pos == 'top') {
    const before = dialog.messages[0].ts.toISOString();
    route.go(dialog.path + '#' + before, {replace: true});
    if (!dialog.startOfHistory) dialog.load({before});
  }
  else if (scrollspy.pos == 'bottom') {
    const after = dialog.messages.slice(-1)[0].ts.toISOString();
    route.go(dialog.path + '#' + after, {replace: true});
    if (!dialog.endOfHistory) dialog.load({after});
  }
  else {
    const els = scrollspy.findVisibleElements('.message[data-ts]', 1);
    route.go(dialog.path + '#' + els[0].dataset.ts, {replace: true});
  }
});

function maybeReloadMessages(route) {
  if (before.hasHash && !route.hash && !dialog.endOfHistory) dialog.load({});
  before.hasHash = route.hash ? true : false;
}

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

async function setDialogFromUser(user) {
  if (user.activeDialog == chatMessages.dialog) return;

  if (unsubscribe.dialog) {
    unsubscribe.dialog();
    if (dialog.setLastRead) dialog.setLastRead();
  }

  if (user.omnibus.debug > 1) console.log('[setDialogFromUser]', user.activeDialog.name);

  dialog = user.activeDialog;
  connection = user.findDialog({connection_id: dialog.connection_id}) || {};
  chatMessages.attach({connection, dialog, user});
  route.update({title: dialog.title});
  unsubscribe.dialog = dialog.subscribe(d => { dialog = d });

  let after = isISOTimeString(route.hash) && new Time(route.hash);
  await dialog.load({after: after ? after.setSeconds(after.getSeconds() - 5).toISOString() : 'maybe'});
  if (after && dialog.messages.length < dialog.chunkSize) {
    const before = dialog.messages[0] && dialog.messages[0].ts.toISOString() || new Time().toISOString();
    await dialog.load({before});
  }
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

<main class="main has-chat" bind:this="{mainEl}"  on:scroll="{scrollspy.onScroll}">
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
        <div class="message__ts has-tooltip" data-content="{message.ts.getHM()}"><div>{message.ts.toLocaleString()}</div></div>
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
