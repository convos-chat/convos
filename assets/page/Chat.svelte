<script>
import {fragment, gotoUrl, pathParts} from '../store/router';
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import {timer} from '../js/util';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ConnectionSettings from '../components/ConnectionSettings.svelte';
import DialogSettings from '../components/DialogSettings.svelte';
import DialogSubject from '../components/DialogSubject.svelte';
import Link from '../components/Link.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import Ts from '../components/Ts.svelte';

const user = getContext('user');

let height = 0;
let scrollDirection = 'down'; // TODO: Change it to up, when scrolling up

function isSameMessage(i) {
  return i == 0 ? false : messages[i].from == messages[i - 1].from;
}

$: dialog = $user.findDialog({connection_id: $pathParts[1], dialog_id: $pathParts[2]}) || user.notifications;
$: dialog.load();
$: fallbackSubject = dialog.frozen || ($pathParts[2] ? l('Private conversation.') : l('Server messages.'));
$: messages = $dialog.messages;
$: settingsComponent = $fragment != 'settings' ? null : dialog.dialog_id ? DialogSettings : ConnectionSettings;

$: if (scrollDirection == 'down') window.scrollTo(0, height);
</script>

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
        <a href="#clear:notifications" on:click|preventDefault="{e => user.readNotifications.perform()}">
          ({dialog.unread})
        </a>
      </h1>
    {/if}
  </ChatHeader>

  {#if messages.length == 0}
    {#if !$pathParts[1]}
      <h2>{l('No notifications.')}</h2>
    {:else if $pathParts[1] == dialog.connection_id}
      <h2>{l(dialog.loading ? 'Loading messages...' : 'No messages.')}</h2>
      <p>{dialog.frozen}</p>
    {:else}
      <h2>{l(dialog.dialog_id ? 'You are not part of this dialog.' : 'Connection does not exist.')}</h2>
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
