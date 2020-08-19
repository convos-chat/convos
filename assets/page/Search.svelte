<script>
import ChatMessage from '../components/ChatMessage.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatMessages from '../js/ChatMessages';
import Icon from '../components/Icon.svelte';
import Time from '../js/Time';
import {focusMainInputElements} from '../js/util';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';
import {route} from '../store/Route';

const chatMessages = new ChatMessages();
const user = getContext('user');

let chatInput;
let dialog = $route.path.indexOf('search') == -1 ? user.notifications : user.search;

$: chatMessages.attach({connection: {}, dialog, user});
$: messages = $dialog.messages;
$: setDialogFromRoute($route);

onMount(() => user.search.on('search', (msg) => search(route, msg)));

function dialogUrl(message) {
  const url = ['', 'chat', message.connection_id, message.dialog_id].map(encodeURIComponent).join('/');
  return route.urlFor(url + '#' + message.ts.toISOString());
}

function gotoDialog(e) {
  if (e.target.closest('a')) return;
  e.preventDefault();
  route.go(e.target.closest('.message').querySelector('a').href);
}

function loadNotifications(route) {
  if (!dialog.is('success') || dialog.last_read <= new Time() - 10000) dialog.load();
  dialog.setLastRead();
}

function search(route, msg) {
  const match = msg ? msg.message : route.param('q');

  if (chatInput) {
    if (!msg) chatInput.setValue(match || '');
    focusMainInputElements('chat_input');
  }
  if (route.param('q') != match) {
    route.go('/search?q=' + encodeURIComponent(match), {replace: true});
  }

  return match ? dialog.load({match}) : dialog.update({messages: []});
}

function setDialogFromRoute(route) {
  const d = route.path.indexOf('search') != -1 ? user.search : user.notifications;
  if (d != dialog) dialog = d;
  return dialog.is('search') ? search(route) : loadNotifications(route);
}
</script>

<ChatHeader>
  <h1><a href="#activeMenu:nav" tabindex="-1"><span>{l(dialog.name)}</span></a></h1>
  {#if $dialog.is('search')}
    <a href="/search" class="btn"><Icon name="search"/></a>
  {:else}
    <a href="/settings/account" class="btn"><Icon name="bell"/></a>
  {/if}
</ChatHeader>

<main class="main" class:has-results="{messages.length}">
  <div>
    <!-- welcome messages / status -->
    {#if messages.length == 0 && !dialog.is('loading')}
      {#if dialog.is('notifications')}
        <h2>{l('No notifications.')}</h2>
      {:else if $route.param('q')}
        <ChatMessage>{l('No search results for "%1".', $route.param('q'))}</ChatMessage>
      {:else if dialog.is('search')}
        <ChatMessage>
          {@html lmd('Search for messages sent by you or others the last %1 days by writing a message in the input field below.', 90)}
          {@html lmd('You can enter a channel name, or use `"conversation:#channel"` to narrow down the search.')}
          {@html lmd('It is also possible to use `"from:some_nick"` to filter out messages from a given user.')}
        </ChatMessage>
      {/if}
    {/if}

    <!-- notifications or search results -->
    {#each messages as message, i}
      {#if chatMessages.dayChanged(messages, i)}
        <div class="message__status-line for-day-changed"><span><Icon name="calendar-alt"/> {message.ts.getHumanDate()}</span></div>
      {/if}

      <div class="{chatMessages.classNames(messages, i)}" on:click="{gotoDialog}">
        <Icon name="pick:{message.fromId}" color="{message.color}"/>
        <div class="message__ts has-tooltip" data-content="{message.ts.getHM()}"><div>{message.ts.toLocaleString()}</div></div>
        <a href="{dialogUrl(message)}" class="message__from" style="color:{message.color}">{l('%1 in %2', message.from, message.dialog_id)}</a>
        <div class="message__text">{@html message.markdown}</div>
      </div>
    {/each}

    <!-- status -->
    {#if $dialog.is('loading')}
      <div class="message__status-line for-loading"><span><Icon name="spinner" animation="spin"/> <i>{l('Loading...')}</i></span></div>
    {/if}
  </div>
</main>

{#if dialog.is('search')}
  <ChatInput dialog="{dialog}" bind:this="{chatInput}"/>
{/if}
