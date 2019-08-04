<script>
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import {pathParts} from '../store/router';
import ChatInput from '../components/ChatInput.svelte';
import DialogSubject from '../components/DialogSubject.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import ServerSettings from '../components/ServerSettings.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import Ts from '../components/Ts.svelte';

const user = getContext('user');

let height = 0;
let scrollDirection = 'down'; // TODO: Change it to up, when scrolling up
let settingsIsVisible = false;
let sidebarIsVisible = false;

function isSameMessage(i) {
  return i == 0 ? false : messages[i].from == messages[i - 1].from;
}

function partDialog() {
  user.send({message: '/part', method: 'send', dialog});
}

function toggleSettings(e) {
  sidebarIsVisible = false;
  settingsIsVisible = !settingsIsVisible;
}

function toggleSidebar(e) {
  settingsIsVisible = false;
  sidebarIsVisible = !sidebarIsVisible;
}

$: dialog = $user.findDialog({connection_id: $pathParts[1], dialog_id: $pathParts[2]}) || user.notifications;
$: dialog.load();
$: fallbackSubject = dialog.frozen || ($pathParts[2] ? l('Private conversation.') : l('Server messages.'));
$: messages = $dialog.messages;

$: if (scrollDirection == 'down') window.scrollTo(0, height);
$: settingsIsVisible = $pathParts && false; // Force to false when path changes
</script>

<SidebarChat visible="{sidebarIsVisible}"/>

<main class="main messages-container" bind:offsetHeight="{height}">
  <header class="header" class:has-visible-settings="{settingsIsVisible}">
    <h1>{$pathParts[2] || $pathParts[1] || l('Notifications')}</h1>
    {#if dialog.dialog_id}
      <small><DialogSubject dialog="{dialog}"/></small>
      <a href="#close" class="header__toggle" on:click|preventDefault="{partDialog}"><Icon name="times"/></a>
    {:else if dialog.connection_id}
      <small><DialogSubject dialog="{dialog}"/></small>
      <a href="#settings" class="header__toggle" on:click|preventDefault="{toggleSettings}"><Icon name="sliders-h"/></a>
    {:else}
      <a href="#clear" class="header__toggle" on:click|preventDefault="{e => user.readNotifications.perform()}"><Icon name="{$user.unread ? 'bell' : 'bell-slash'}"/></a>
    {/if}

    <a href="#menu" class="header__hamburger" on:click|preventDefault="{toggleSidebar}"><Icon name="bars"/></a>
    <ServerSettings dialog="{dialog}"/>
  </header>

  {#if messages.length == 0}
    {#if !$pathParts[1]}
      <h2>{l('No notifications.')}</h2>
    {:else if $pathParts[1] == dialog.connection_id}
      <h2>{l(dialog.loading ? 'Loading messages...' : 'No messages.')}</h2>
      <p>{dialog.frozen}</p>
    {:else}
      <h2>{l('You are not part of this dialog.')}</h2>
    {/if}
  {/if}

  {#each messages as message, i}
    <div class="message" class:is-same="{isSameMessage(i)}" class:is-hightlighted="{message.highlight}">
      <Ts val="{message.ts}"/>
      <Link className="message_from" href="/chat/{$pathParts[1]}/{message.from}">{message.from}</Link>
      <div class="message_text">{@html message.markdown}</div>
    </div>
  {/each}
</main>

{#if dialog.connection_id}
<ChatInput dialog="{dialog}"/>
{/if}
