<script>
import {afterUpdate, getContext, onMount, tick} from 'svelte';
import {debounce, q} from '../js/util';
import {gotoUrl, pathParts, currentUrl} from '../store/router';
import {l} from '../js/i18n';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ConnectionSettings from '../components/ConnectionSettings.svelte';
import DialogSettings from '../components/DialogSettings.svelte';
import DialogSubject from '../components/DialogSubject.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import SidebarChat from '../components/SidebarChat.svelte';

const user = getContext('user');
const w = window;

let height = 0;
let lastHeight = 0;
let observer;
let scrollPos = 'bottom';

$: connection = $user.findDialog({connection_id: $pathParts[1]});
$: currentNick = connection ? connection.nick : user.email;
$: dialog = $user.findDialog({connection_id: $pathParts[1], dialog_id: $pathParts[2]}) || user.notifications;
$: hasValidPath = $pathParts.slice(1).join('/') == decodeURIComponent(dialog.path);
$: isLoading = dialog.is('loading');
$: fallbackSubject = dialog.frozen || ($pathParts[2] ? l('Private conversation.') : l('Server messages.'));
$: messages = hasValidPath ? $dialog.messages : [];
$: settingsComponent = $currentUrl.hash != '#settings' || !hasValidPath ? null : dialog.dialog_id ? DialogSettings : ConnectionSettings;

$: if (dialog.connection_id) dialog.load();

$: if (scrollPos == 'bottom') w.scrollTo(0, height);

$: if (lastHeight && lastHeight < height) {
  w.scrollTo(0, height - lastHeight);
  lastHeight = 0;
}

onMount(() => {
  // Clean up any embeds added from a previous chat
  q(document, '.message__embed', embedEl => embedEl.remove());
});

afterUpdate(() => {
  observer = observer || new IntersectionObserver(observed, {rootMargin: '0px'});
  q(document, '.message', messageEl => observer.observe(messageEl));
});

function addDialog(e) {
  if (connection) connection.addDialog(e.target.closest('a').href.replace(/.*#add:/, ''));
}

function observed(entries, observer) {
  entries.forEach(async ({isIntersecting, target}) => {
    if (!isIntersecting) return;

    const message = messages[target.dataset.index];
    if (!message) return;

    const tsClass = 'has-ts-' + message.dt.toEpoch();
    await $dialog.loadEmbeds(message);

    q(target, '.message__embed', embedEl => {
      if (!embedEl.classList.contains(tsClass)) embedEl.remove();
    });

    message.embeds.forEach(embed => {
      if (!embed.el || target.querySelector('.' + tsClass)) return;
      if (embed.provider) $user.loadProvider(embed.provider);
      target.appendChild(embed.el);
      embed.el.classList.add(tsClass);
    });
  });
}

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
        <a href="#clear:notifications" on:click|preventDefault="{e => user.readNotificationsOp.perform()}">
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
    {/if}
  {/if}

  {#if $pathParts[2] && !dialog.dialog_id}
    <h2>{l('You are not part of this conversation.')}</h2>
    <p>Do you want to add the conversation?</p>
    <p>
      <a href="#add:{$pathParts[2]}" on:click="{addDialog}" class="btn">Yes</a>
      <Link href="/chat" className="btn">{l('No')}</Link>
    </p>
  {:else if $pathParts[1] && !connection}
    <h2>{l('Connection does not exist.')}</h2>
    <p>{l('Do you want to make a new connection?')}</p>
    <p>
      <Link href="/add/connection?server={encodeURIComponent($pathParts[1])}" className="btn">{l('Yes')}</Link>
      <Link href="/chat" className="btn">{l('No')}</Link>
    </p>
  {/if}

  {#if isLoading && scrollPos == 'top'}
    <div class="message-status-line for-loading"><span>{l('Loading messages...')}</span></div>
  {/if}

  {#each messages as message, i}
    {#if message.endOfHistory}
      <div class="message-status-line for-end-of-history"><span>{l('End of history')}</span></div>
    {:else if message.dayChanged}
      <div class="message-status-line for-day-changed"><span>{l('Day changed')}</span></div>
    {/if}

    <div class="message is-type-{message.type || 'notice'}"
      class:is-sent-by-you="{message.from == currentNick}"
      class:is-hightlighted="{message.highlight}"
      class:has-not-same-from="{!message.isSameSender && !message.dayChanged}"
      class:has-same-from="{message.isSameSender && !message.dayChanged}"
      data-index="{i}">

      <Icon name="{message.from == currentNick ? user.icon : 'random:' + message.from}" family="solid" style="color:{message.color}"/>
      <b class="message__ts" title="{message.dt.toLocaleString()}">{message.dt.toHuman()}</b>
      <Link className="message__from" href="/chat/{$pathParts[1]}/{message.from}" style="color:{message.color}">{message.from}</Link>
      <div class="message__text">{@html message.markdown}</div>
    </div>
  {/each}

  {#if dialog.connection_id}
    <ChatInput dialog="{dialog}"/>
  {/if}
</main>
