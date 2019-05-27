<script>
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import {md} from '../js/md';
import {connections, dialogs} from '../store/user';
import {pathParts} from '../store/router';
import DialogSettings from '../components/DialogSettings.svelte';
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
let subject = ''; // TODO: Get it from Api

function toggleSettings(e) {
  settingsIsVisible = !settingsIsVisible;
}

pathParts.subscribe(async ($pathParts) => {
  messages = [];
  settingsIsVisible = false;
  if (!$pathParts[1]) return;
  const operationId = $pathParts[2] ? 'dialogMessages' : 'connectionMessages';
  const res = await api.execute(operationId, {connection_id: $pathParts[1], dialog_id: $pathParts[2]});
  messages = res.messages || [];
});

$: if (scrollDirection == 'down') window.scrollTo(0, height);
$: connection = $connections.filter(conn => conn.connection_id == $pathParts[1])[0] || {};
$: dialog = $dialogs.filter(d => d.connection_id == $pathParts[1] && d.dialog_id == $pathParts[2])[0] || {};
$: fallbackSubject = dialog.frozen || ($pathParts[2] ? l('Private conversation.') : l('Server messages.'));
$: settingComponent = $pathParts[2] ? DialogSettings : ServerSettings;
</script>

<SidebarChat/>

<main class="main-app-pane" class:has-visible-settings="{settingsIsVisible}" bind:offsetHeight="{height}">
  <h1 class="main-header">
    <span>{$pathParts[2] || $pathParts[1] || l('TODO')}</span>
    <small>{subject || l(fallbackSubject)}</small>
    <a href="#settings" class="main-header_settings-toggle" on:click|preventDefault="{toggleSettings}"><Icon name="sliders-h"/></a>
    <StateIcon obj="{dialog.dialog_id ? dialog : connection}"/>
  </h1>

  {#each messages as message}
    <div class="message" class:is-hightlight="{message.highlight}">
      <Ts val="{message.ts}"/>
      <Link className="message_link" href="/chat/{$pathParts[1]}/{message.from}">{message.from}</Link>
      <div class="message_text">{@html md(message.message)}</div>
    </div>
  {/each}

  <svelte:component this={settingComponent} connectionId="{$pathParts[1]}" dialogId="{$pathParts[2]}"/>
</main>