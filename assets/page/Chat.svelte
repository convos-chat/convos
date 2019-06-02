<script>
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import {md} from '../js/md';
import {pathParts} from '../store/router';
import ChatInput from '../components/ChatInput.svelte';
import DialogSettings from '../components/DialogSettings.svelte';
import DialogSubject from '../components/DialogSubject.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import ServerSettings from '../components/ServerSettings.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import StateIcon from '../components/StateIcon.svelte';
import Ts from '../components/Ts.svelte';

const user = getContext('user');
const connectionMessagesOp = user.api.operation('connectionMessages');
const dialogMessagesOp = user.api.operation('dialogMessages');

let height = 0;
let messages = [];
let scrollDirection = 'down'; // TODO: Change it to up, when scrolling up
let settingsIsVisible = false;

async function getMessages($pathParts) {
  messages = [];
  settingsIsVisible = false;

  if ($pathParts[1]) {
    const op = $pathParts[2] ? dialogMessagesOp : connectionMessagesOp;
    await op.perform({connection_id: $pathParts[1], dialog_id: $pathParts[2]});
    messages = op.res.body.messages || [];
  }
  else {
    messages = $user.notifications;
  }
}

function isSameMessage(i) {
  return i == 0 ? false : messages[i].from == messages[i - 1].from;
}

function toggleSettings(e) {
  settingsIsVisible = !settingsIsVisible;
}

$: if (scrollDirection == 'down') window.scrollTo(0, height);
$: connection = $user.connections.filter(conn => conn.id == $pathParts[1])[0] || {};
$: dialog = $user.dialogs.filter(d => d.connection_id == $pathParts[1] && d.id == $pathParts[2])[0] || {};
$: fallbackSubject = dialog.frozen || (isDisconnected ? l('Disconnected.') : $pathParts[2] ? l('Private conversation.') : l('Server messages.'));
$: isDisconnected = connection.state == 'disconnected';
$: settingComponent = $pathParts[2] ? DialogSettings : ServerSettings;
$: getMessages($pathParts);
</script>

<SidebarChat/>

<main class="main-app-pane" class:has-visible-settings="{settingsIsVisible}" bind:offsetHeight="{height}">
  <h1 class="main-header">
    <span>{$pathParts[2] || $pathParts[1] || l('Notifications')}</span>
    {#if connection.id}
      <small><DialogSubject dialog="{dialog.isDialog ? dialog : connection}"/></small>
      <a href="#settings" class="main-header_settings-toggle" on:click|preventDefault="{toggleSettings}"><Icon name="sliders-h"/></a>
      <StateIcon obj="{dialog.isDialog ? dialog : connection}"/>
    {:else}
      <a href="#clear" class="main-header_settings-toggle" on:click|preventDefault="{e => user.readNotifications.perform(e.target)}"><Icon name="{$user.unread ? 'bell' : 'bell-slash'}"/></a>
    {/if}
  </h1>

  {#if messages.length == 0}
    <h2>{l(connection.id ? 'No messages.' : 'No notifications.')}</h2>
  {/if}

  {#each messages as message, i}
    <div class="message" class:is-same="{isSameMessage(i)}" class:is-hightlight="{message.highlight}">
      <Ts val="{message.ts}"/>
      <Link className="message_from" href="/chat/{$pathParts[1]}/{message.from}">{message.from}</Link>
      <div class="message_text">{@html md(message.message)}</div>
    </div>
  {/each}

  {#if connection.id}
  <ChatInput connection="{connection}" dialog="{dialog}"/>
  {/if}

  <svelte:component this={settingComponent} connection="{connection}" dialog="{dialog}"/>
</main>
