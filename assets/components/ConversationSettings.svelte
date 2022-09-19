<script>
import Button from './form/Button.svelte';
import Checkbox from './form/Checkbox.svelte';
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import Operation from '../store/Operation';
import OperationStatus from '../components/OperationStatus.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {activeMenu, viewport} from '../store/viewport';
import {awayMessage} from '../js/chatHelpers';
import {getChannelMode} from '../js/constants';
import {fly} from 'svelte/transition';
import {onMount, tick} from 'svelte';
import {l, lmd} from '../store/I18N';
import {modeClassNames} from '../js/util';

export let conversation;
export let transition;

const saveConversationSettingsOp = new Operation({api: false, id: 'saveConversationSettings'});

let checkboxes = {
  invite_only: false,
  moderated: false,
  password: false,
  prevent_external_send: false,
  topic_protection: false,
};

let password = '';
let rawMessages = false;
let topic = '';
let wantNotifications = false;

$: participants = $conversation.participants;
$: isPrivate = $conversation.is('private');
$: isOperator = $participants.me().modes.operator;

onMount(async () => {
  if (Object.keys(conversation.modes).length === 0 && !isPrivate) await new Promise(r => conversation.send('/mode', r));
  await tick();
  checkboxes = Object.assign({}, checkboxes, conversation.modes);
  rawMessages = conversation.messages.raw;
  topic = conversation.topic;
  wantNotifications = conversation.wantNotifications;
});

function partConversation() {
  conversation.send('/part', (res) => !res.errrors && ($activeMenu = ''));
}

function saveChannelModes() {
  const setModes = [];
  for (const name in checkboxes) {
    if (name === 'password' && checkboxes[name]) {
      if (password) conversation.send(isOperator ? '/mode +k ' + password : '/join ' + conversation.name + ' ' + password);
      password = '';
    }
    else if (checkboxes[name] !== (conversation.modes[name] || false)) {
      setModes.push((checkboxes[name] ? '+' : '-') + getChannelMode(name));
    }
  }

  return isOperator && setModes.length && conversation.send('/mode ' + setModes.join(''));
}

function saveChannelTopic() {
  if (!isOperator && conversation.modes.topic_protection) return false;
  return topic !== conversation.topic && conversation.send('/topic ' + topic);
}

async function saveConversationSettings() {
  saveConversationSettingsOp.update({status: 'loading'});
  await saveConversationSettingsOp.on('update');
  conversation.update({wantNotifications});
  conversation.messages.update({raw: rawMessages});
  saveChannelModes();
  saveChannelTopic();
  await tick();
  saveConversationSettingsOp.update({status: 'success'});
}

function updateInfo() {
  conversation.send('/whois ' + conversation.name, (e) => e.stopPropagation());
}
</script>

<div class="sidebar-left" transition:fly="{transition}">
  <div class="sidebar-header">
    <h2>{$l('Conversation')}</h2>
    <a href="#settings" class="btn-hallow can-toggle is-active" on:click="{activeMenu.toggle}">
      <Icon name="bars"/><Icon name="times"/>
    </a>
  </div>

  <p>
    {#if $conversation.frozen}
      {$l('Conversation with %1 is frozen. Reason: %2', conversation.name, $l(conversation.frozen))}
    {:else if isPrivate}
      <span>{@html $lmd(...awayMessage($conversation.info))}</span>
      <br><small><a href="#update" on:click|preventDefault="{updateInfo}">{$l('Update information')}</a></small>
    {:else if isOperator}
      {$l('You are channel operator in %1.', conversation.name)}
    {:else}
      {$l('You are not a channel operator in %1.', conversation.name)}
    {/if}
  </p>

  <form method="post" on:submit|preventDefault="{saveConversationSettings}">
    {#if !isPrivate}
      {#if isOperator || !$conversation.modes.topic_protection}
        <TextArea name="topic" bind:value="{topic}" placeholder="{$l('No topic is set.')}">
          <span slot="label">{$l('Topic')}</span>
        </TextArea>
      {:else}
        <div class="text-field">
          <label for="nothing">{$l('Topic')}</label>
          <div class="input">{@html $lmd(conversation.topic || 'No topic is set.')}</div>
        </div>
      {/if}
    {/if}

    {#if $conversation.hasOwnProperty('wantNotifications')}
      <Checkbox name="want_notifications" bind:value="{wantNotifications}">
        <span slot="label">{$l('Notify me on new messages')}</span>
      </Checkbox>
    {/if}

    <Checkbox name="raw_messages" bind:value="{rawMessages}">
      <span slot="label">{$l('Show raw messages')}</span>
    </Checkbox>

    {#if !isPrivate}
      <nav class="sidebar-left__nav">
        <h3>{$l('Conversation modes')}</h3>
        <Checkbox badge name="invite_only" bind:value="{checkboxes.invite_only}" disabled="{!isOperator}">
          <span slot="label">{$l('Invite only')} <b class="badge">{checkboxes.invite_only ? '+' : '-'}{getChannelMode('invite_only')}</b></span>
        </Checkbox>
        <Checkbox badge name="moderated" bind:value="{checkboxes.moderated}" disabled="{!isOperator}">
          <span slot="label">{$l('Moderated')} <b class="badge">{checkboxes.moderated ? '+' : '-'}{getChannelMode('moderated')}</b></span>
        </Checkbox>
        <Checkbox badge name="prevent_external_send" bind:value="{checkboxes.prevent_external_send}" disabled="{!isOperator}">
          <span slot="label">{$l('Prevent external send')} <b class="badge">{checkboxes.prevent_external_send ? '+' : '-'}{getChannelMode('prevent_external_send')}</b></span>
        </Checkbox>
        <Checkbox badge name="topic_protection" bind:value="{checkboxes.topic_protection}" disabled="{!isOperator}">
          <span slot="label">{$l('Protected topic')} <b class="badge">{checkboxes.topic_protection ? '+' : '-'}{getChannelMode('topic_protection')}</b></span>
        </Checkbox>
        <Checkbox badge name="password" bind:value="{checkboxes.password}" disabled="{!isOperator}">
          <span slot="label">{$l('Password')} <b class="badge">{checkboxes.password ? '+' : '-'}{getChannelMode('password')}</b></span>
        </Checkbox>
        {#if checkboxes.password}
          <TextField type="password" name="password" bind:value="{password}">
            <span slot="label">{$l('Password')}</span>
          </TextField>
        {/if}

        {#if !isOperator}
          <p><i>{$l('Only operators can change modes.')}</i></p>
        {/if}
      </nav>
    {/if}

    <div class="form-actions">
      <Button icon="save"><span>{$l('Save')}</span></Button>
      <Button type="button" on:click="{partConversation}" icon="sign-out-alt"><span>{$l('Leave')}</span></Button>
    </div>
    <OperationStatus op="{saveConversationSettingsOp}"/>
  </form>

  {#if !conversation.frozen && $viewport.hasRightColumn}
    <nav class="sidebar-left__nav">
      <h3>{$l('Participants (%1)', $participants.length)}</h3>
      {#each $participants.toArray() as participant}
        <Link href="/chat/{conversation.connection_id}/{encodeURIComponent(participant.nick)}" class="participant {modeClassNames(participant.modes)}">
          <div>{participant.nick}</div>
        </Link>
      {/each}
    </nav>
  {/if}
</div>
