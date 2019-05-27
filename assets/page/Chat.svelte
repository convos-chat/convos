<script>
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import {md} from '../js/md';
import {connections, dialogs, notifications, unread} from '../store/user';
import {pathParts} from '../store/router';
import DialogSettings from '../components/DialogSettings.svelte';
import DialogSubject from '../components/DialogSubject.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import ServerSettings from '../components/ServerSettings.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import StateIcon from '../components/StateIcon.svelte';
import Ts from '../components/Ts.svelte';

const api = getContext('api');

let height = 0;
let messages = [];
let scrollDirection = 'down'; // TODO: Change it to up, when scrolling up
let settingsIsVisible = false;

function clearNotifications(e) {
  alert('TODO');
}

function isSame(i) {
  return i == 0 ? false : messages[i].from == messages[i - 1].from;
}

function toggleSettings(e) {
  settingsIsVisible = !settingsIsVisible;
}

pathParts.subscribe(async ($pathParts) => {
  messages = [];
  settingsIsVisible = false;
  if (!$pathParts[1]) return (messages = $notifications);
  const operationId = $pathParts[2] ? 'dialogMessages' : 'connectionMessages';
  const res = await api.execute(operationId, {connection_id: $pathParts[1], dialog_id: $pathParts[2]});
  messages = res.messages || [];
});

$: if (scrollDirection == 'down') window.scrollTo(0, height);
$: connection = $connections.filter(conn => conn.connection_id == $pathParts[1])[0] || {};
$: dialog = $dialogs.filter(d => d.connection_id == $pathParts[1] && d.dialog_id == $pathParts[2])[0] || {};
$: fallbackSubject = dialog.frozen || (isDisconnected ? l('Disconnected.') : $pathParts[2] ? l('Private conversation.') : l('Server messages.'));
$: isDisconnected = connection.state == 'disconnected';
$: settingComponent = $pathParts[2] ? DialogSettings : ServerSettings;
</script>

<SidebarChat/>

<main class="main-app-pane" class:has-visible-settings="{settingsIsVisible}" bind:offsetHeight="{height}">
  <h1 class="main-header">
    <span>{$pathParts[2] || $pathParts[1] || l('Notifications')}</span>
    {#if connection.connection_id}
      <small><DialogSubject obj="{dialog.dialog_id ? dialog : connection}"/></small>
      <a href="#settings" class="main-header_settings-toggle" on:click|preventDefault="{toggleSettings}"><Icon name="sliders-h"/></a>
      <StateIcon obj="{dialog.dialog_id ? dialog : connection}"/>
    {:else}
      <a href="#clear" class="main-header_settings-toggle" on:click|preventDefault="{clearNotifications}"><Icon name="{$unread ? 'bell' : 'bell-slash'}"/></a>
    {/if}
  </h1>

  {#if messages.length == 0}
    <h2>{l(connection.connection_id ? 'No messages.' : 'No notifications.')}</h2>
  {/if}

  {#each messages as message, i}
    <div class="message" class:is-same="{isSame(i)}" class:is-hightlight="{message.highlight}">
      <Ts val="{message.ts}"/>
      <Link className="message_from" href="/chat/{$pathParts[1]}/{message.from}">{message.from}</Link>
      <div class="message_text">{@html md(message.message)}</div>
    </div>
  {/each}

  <svelte:component this={settingComponent} connectionId="{$pathParts[1]}" dialogId="{$pathParts[2]}"/>
</main>