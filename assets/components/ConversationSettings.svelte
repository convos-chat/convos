<script>
import Button from './form/Button.svelte';
import ChatParticipants from '../components/ChatParticipants.svelte';
import Checkbox from './form/Checkbox.svelte';
import Operation from '../store/Operation';
import OperationStatus from '../components/OperationStatus.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {activeMenu, viewport} from '../store/viewport';
import {awayMessage} from '../js/chatHelpers';
import {fly} from 'svelte/transition';
import {getChannelMode} from '../js/constants';
import {l, lmd} from '../store/I18N';
import {route} from '../store/Route';
import {tick} from 'svelte';

export let conversation;

const saveConversationSettingsOp = new Operation({api: false, id: 'saveConversationSettings'});

let checkboxes = {
  invite_only: false,
  moderated: false,
  password: false,
  prevent_external_send: false,
  topic_protection: false,
};

let conversationPath = '';
let password = '';
let topic = '';

$: participants = $conversation.participants;
$: isPrivate = $conversation.is('private');
$: isOperator = $participants.me().modes.operator;
$: if (conversation.path != conversationPath) { conversationPath = conversation.path; updateState() }

function partConversation() {
  conversation.send('/part', (res) => {
    if (res.errrors) return;
    $activeMenu = '';
    route.removeFromHistory(location.href);
    route.go(route.history.slice(-1)[0] || '/settings/conversation?connection_id=' + (conversation.connection_id || ''));
  });
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
  saveChannelModes();
  saveChannelTopic();
  await tick();
  saveConversationSettingsOp.update({status: 'success'});
}

async function updateState() {
  if (Object.keys(conversation.modes).length === 0 && !isPrivate && !conversation.frozen) {
    conversation.send('/mode', () => {
      checkboxes = Object.assign({}, checkboxes, conversation.modes);
      topic = conversation.topic;
    });
  }
}

function updateInfo() {
  conversation.send('/whois ' + conversation.name, (e) => e.stopPropagation());
}
</script>

{#if $viewport.hasRightColumn || $activeMenu === 'settings'}
  <div transition:fly="{$viewport.sidebarTransition}"
    class:sidebar-left={!$viewport.hasRightColumn}
    class:sidebar-right={$viewport.hasRightColumn}>
    <form method="post" on:submit|preventDefault="{saveConversationSettings}">
      <h3>{$l('Settings')}</h3>
      {#if Object.hasOwn($conversation, 'wantNotifications')}
        <Checkbox name="want_notifications" bind:value="{conversation.wantNotifications}">
          <span slot="label">{$l('Notify me on new messages')}</span>
        </Checkbox>
      {/if}

      <Checkbox name="raw_messages" bind:value="{conversation.messages.raw}">
        <span slot="label">{$l('Show raw messages')}</span>
      </Checkbox>

      {#if !isPrivate}
        <TextArea name="topic" bind:value="{topic}" placeholder="{$l('No topic is set.')}" readonly={!isOperator || !$conversation.modes.topic_protection}>
          <span slot="label">{$l('Topic')}</span>
        </TextArea>
      {/if}

      <p>
        {#if $conversation.frozen}
          {$l('Conversation with %1 is frozen. Reason: %2', conversation.name, $l(conversation.frozen))}
        {:else if isPrivate}
          <span>{@html $lmd(...awayMessage($conversation.info))}</span>
          <br><small><a href="#update" on:click|preventDefault="{updateInfo}">{$l('Update information')}</a></small>
        {/if}
      </p>

      {#if !isPrivate}
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
      {/if}

      <div class="form-actions">
        {#if !isPrivate}
          <Button icon="save" op="{saveConversationSettingsOp}"><span>{$l('Save')}</span></Button>
        {/if}
        <Button type="button" on:click="{partConversation}" icon="sign-out-alt"><span>{$l('Leave')}</span></Button>
      </div>
      <OperationStatus op="{saveConversationSettingsOp}"/>
    </form>

    <ChatParticipants conversation="{conversation}"/>
  </div>
{/if}
