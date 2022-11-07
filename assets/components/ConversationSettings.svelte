<script>
import Button from './form/Button.svelte';
import Checkbox from './form/Checkbox.svelte';
import Icon from './Icon.svelte';
import Operation from '../store/Operation';
import OperationStatus from '../components/OperationStatus.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {activeMenu, viewport} from '../store/viewport';
import {awayMessage} from '../js/chatHelpers';
import {fly, slide} from 'svelte/transition';
import {getChannelMode} from '../js/constants';
import {l, lmd} from '../store/I18N';
import {onMount, tick} from 'svelte';
import {userGroupHeadings} from '../js/constants';

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

function participantsGrouped($participants) {
  const grouped = {};
  const groups = [];
  let id = -1;

  for (const p of $participants) {
    if (id != p.group) {
      id = p.group;
      groups.push(id);
      grouped[id] = {id, participants: [], heading: userGroupHeadings[id] || userGroupHeadings[0]};
    }

    grouped[id].participants.push(p);
  }

  return groups.map(k => grouped[k]);
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

<div class="sidebar-right" transition:fly="{transition}">
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

  <p>
    <Button type="button" on:click="{partConversation}" icon="sign-out-alt"><span>{$l('Leave')}</span></Button>
  </p>

  <Checkbox icon="caret" name="show_settings" bind:value="{$viewport.showSettings}">
    <span slot="label">{$l('Settings')}</span>
  </Checkbox>

  {#if $viewport.showSettings}
    <form class="form-group" transition:slide="{{duration: 150}}" method="post" on:submit|preventDefault="{saveConversationSettings}">
      {#if !isPrivate}
        {#if isOperator || !$conversation.modes.topic_protection}
          <TextArea name="topic" bind:value="{topic}" placeholder="{$l('No topic is set.')}">
            <span slot="label">{$l('Topic')}</span>
          </TextArea>
        {/if}
      {/if}

      {#if Object.hasOwn($conversation, 'wantNotifications')}
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
    </form>
  {/if}

  {#each participantsGrouped($participants.toArray()) as group}
    <Checkbox icon="caret" name="show_settings" bind:value="{$viewport[group.id]}">
      <span slot="label">{$l(group.heading)}</span>
    </Checkbox>
    {#if $viewport[group.id]}
      <nav class="form-group participants" transition:slide="{{duration: 150}}">
        {#each group.participants as p}
          <a href="#action:join:{p.nick}" class="participant prevent-default">
            <Icon name="pick:{p.nick}" family="solid" color="{p.color}"/>
            <span>{p.nick}</span>
          </a>
        {/each}
      </nav>
    {/if}
  {/each}

  <div/><!-- add bottom padding to the menu -->
</div>
