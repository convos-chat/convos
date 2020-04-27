<script>
import ChatMessage from '../components/ChatMessage.svelte';
import ChatMessagesContainer from '../components/ChatMessagesContainer.svelte';
import ChatMessagesStatusLine from '../components/ChatMessagesStatusLine.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import Icon from '../components/Icon.svelte';
import {focusMainInputElements} from '../js/util';
import {getContext, onMount} from 'svelte';
import ChatMessages from '../js/ChatMessages';
import {l} from '../js/i18n';
import {route} from '../store/Route';

const chatMessages = new ChatMessages();
const user = getContext('user');

let chatInput;
let dialog = $route.path.indexOf('search') == -1 ? user.notifications : user.search;

$: chatMessages.attach({connection: {}, dialog: $dialog, user});
$: messages = $dialog.messages;
$: load($route, {});

onMount(() => {
  load(route, {query: true});
});

function dialogUrl(message) {
  const url = ['', 'chat', message.connection_id, message.dialog_id].map(encodeURIComponent).join('/');
  return url + '#' + message.ts.toISOString();
}

function gotoDialog(e) {
  if (e.target.closest('a')) return;
  e.preventDefault();
  route.go(e.target.closest('.message').querySelector('a').href);
}

function load(route, changed) {
  const match = route.param('q');
  dialog = $route.path.indexOf('search') == -1 ? user.notifications : user.search;
  if (dialog.is('search') && (!changed.query || typeof match != 'string')) return;
  if (chatInput) chatInput.setValue(match);
  dialog.load({match});
  if (chatInput) focusMainInputElements('chat_input');
  route.update({title: dialog.is('search') ? l('Search for "%1"', match) : l('Notifications')});
}
</script>

<ChatHeader>
  <h1><a href="#activeMenu:nav" tabindex="-1"><Icon name="{dialog.is('search') ? 'search' : 'bell'}"/><span>{l(dialog.name)}</span></a></h1>
</ChatHeader>

<main class="main has-search-results">
  <ChatMessagesContainer dialog="{dialog}">
    {#if messages.length == 0 && !$dialog.is('loading')}
      {#if $dialog.is('notifications')}
        <h2>{l('No notifications.')}</h2>
      {:else if $route.param('q')}
        <ChatMessage>{l('No search results for "%1".', $route.param('q'))}</ChatMessage>
      {:else if $dialog.is('search')}
        <ChatMessage>
          {l('Search for messages sent by you or others the last %1 days by writing a message in the input field below.', 90)}
          {l('You can enter a channel name, or use `"conversation:#channel"` to narrow down the search.')}
        </ChatMessage>
      {/if}
    {/if}

    {#each messages as message, i}
      {#if chatMessages.dayChanged(messages, i)}
        <ChatMessagesStatusLine class="for-day-changed" icon="calendar-alt">{message.ts.getHumanDate()}</ChatMessagesStatusLine>
      {/if}

      <div class="{chatMessages.classNames(messages, i)}" on:click="{gotoDialog}">
        <Icon name="pick:{message.fromId}" color="{message.color}"/>
        <b class="message__ts" aria-labelledby="{message.id + '_ts'}">{message.ts.getHM()}</b>
        <div role="tooltip" id="{message.id + '_ts'}">{message.ts.toLocaleString()}</div>
        <a href="{dialogUrl(message)}" class="message__from" style="color:{message.color}">{l('%1 in %2', message.from, message.dialog_id)}</a>
        <div class="message__text">{@html message.markdown}</div>
      </div>
    {/each}
  </ChatMessagesContainer>
</main>

{#if dialog.is('search')}
  <ChatInput dialog="{dialog}" bind:this="{chatInput}"/>
{/if}
