<script>
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import {pathParts} from '../store/router';
import {timer} from '../js/util';
import ChatInput from '../components/ChatInput.svelte';
import DialogSubject from '../components/DialogSubject.svelte';
import DialogSettings from '../components/DialogSettings.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import ServerSettings from '../components/ServerSettings.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import Ts from '../components/Ts.svelte';

const settingsComponents = {DialogSettings, ServerSettings};
const user = getContext('user');

let height = 0;
let scrollDirection = 'down'; // TODO: Change it to up, when scrolling up
let visibleSection = '';

function isSameMessage(i) {
  return i == 0 ? false : messages[i].from == messages[i - 1].from;
}

async function toggleVisibility(e) {
  const aEl = e.target.closest('a');
  const sectionName = aEl ? aEl.href.replace(/.*#/, '') : settingsLink;
  visibleSection = visibleSection == sectionName ? '' : sectionName;
}

$: dialog = $user.findDialog({connection_id: $pathParts[1], dialog_id: $pathParts[2]}) || user.notifications;
$: dialog.load();
$: fallbackSubject = dialog.frozen || ($pathParts[2] ? l('Private conversation.') : l('Server messages.'));
$: messages = $dialog.messages;
$: settingsLink = $dialog.dialog_id ? 'DialogSettings' : 'ServerSettings';

$: if (scrollDirection == 'down') window.scrollTo(0, height);
$: visibleSection = $pathParts && ''; // Force to false when path changes
</script>

<SidebarChat visible="{visibleSection == 'SidebarChat'}"/>

<main class="main messages-container" bind:offsetHeight="{height}">
  <header class="header" class:has-visible-settings="{visibleSection.indexOf('Settings') != -1}">
    <h1 on:click|preventDefault="{toggleVisibility}">{$pathParts[2] || $pathParts[1] || l('Notifications')}</h1>
    {#if dialog.dialog_id || dialog.connection_id}
      <small><DialogSubject dialog="{dialog}"/></small>
      <a href="#{settingsLink}" class="header__toggle" on:click|preventDefault="{toggleVisibility}"><Icon name="chevron-down"/></a>
    {:else}
      <a href="#clear" class="header__toggle" on:click|preventDefault="{e => user.readNotifications.perform()}"><Icon name="{$user.unread ? 'bell' : 'bell-slash'}"/></a>
    {/if}

    <!-- hamburger for small screens -->
    <a href="#SidebarChat" class="header__hamburger" on:click|preventDefault="{toggleVisibility}"><Icon name="bars"/></a>

    <svelte:component this={settingsComponents[visibleSection]} {dialog}/>
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
