<script>
import Button from './form/Button.svelte';
import Checkbox from './form/Checkbox.svelte';
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import Operation from '../store/Operation';
import OperationStatus from '../components/OperationStatus.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {activeMenu, viewport} from '../store/writable';
import {channelModeCharToModeName, getChannelMode} from '../js/constants';
import {createForm} from '../store/form';
import {fly} from 'svelte/transition';
import {getContext, onMount, tick} from 'svelte';
import {l, lmd} from '../store/I18N';
import {modeClassNames, ucFirst} from '../js/util';

export let conversation;
export let transition;

const form = createForm({password: ''});
const user = getContext('user');
const saveConversationSettingsOp = new Operation({api: false, id: 'saveConversationSettings'});

const toggleModes = [
  'invite_only',
  'moderated',
  'password',
  'prevent_external_send',
  'topic_protection',
];

$: participants = $conversation.participants;
$: isPrivate = $conversation.is('private');
$: isOperator = $participants.me().modes.operator;
$: modes = Object.keys($conversation.modes).sort().filter(k => conversation.modes[k]);

onMount(async () => {
  form.set({topic: conversation.topic, want_notifications: conversation.wantNotifications});
  if (Object.keys(conversation.modes).length == 0 && !isPrivate) await new Promise(r => conversation.send('/mode', r));
  await tick();
  const fields = {};
  for (const mode of toggleModes) fields['mode_' + mode] = conversation.modes[mode] || false;
  form.set(fields);
});

function partConversation() {
  conversation.send('/part', (res) => !res.errrors && ($activeMenu = ''));
}

function saveChannelModes() {
  const setModes = [];
  for (const mode of toggleModes) {
    const checked = form.get('mode_' + mode) || false;
    if (mode == 'password' && checked) {
      const password = form.get('password');
      if (password) conversation.send(isOperator ? '/mode +k ' + password : '/join ' + conversation.name + ' ' + password);
      form.set({password: ''});
    }
    else if (checked != (conversation.modes[mode] || false)) {
      setModes.push((checked ? '+' : '-') + getChannelMode(mode));
    }
  }

  return isOperator && setModes.length && conversation.send('/mode ' + setModes.join(''));
}

function saveChannelTopic() {
  if (!isOperator && conversation.modes.topic_protection) return false;
  return form.get('topic') != conversation.topic && conversation.send('/topic ' + form.get('topic'));
}

async function saveConversationSettings() {
  saveConversationSettingsOp.update({status: 'loading'});
  await saveConversationSettingsOp.on('update');
  conversation.update({wantNotifications: form.get('want_notifications') || false});
  saveChannelModes();
  saveChannelTopic();
  await tick();
  saveConversationSettingsOp.update({status: 'success'});
}
</script>

<div class="sidebar-left" transition:fly="{transition}">
  <div class="sidebar-header">
    <h2>{$l('Conversation')}</h2>
    <a href="#settings" class="btn-hallow is-active" on:click="{activeMenu.toggle}"><Icon name="times"/></a>
  </div>

  <p>
    {#if conversation.frozen}
      {$l('Conversation with %1 is frozen. Reason: %2', conversation.name, $l(conversation.frozen))}
    {:else if isPrivate}
      {$l('Private conversation with %1.', conversation.name)}
    {:else if isOperator}
      {$l('You are channel operator in %1.', conversation.name)}
    {:else}
      {$l('You are not a channel operator in %1.', conversation.name)}
    {/if}
  </p>

  <form method="post" on:submit|preventDefault="{saveConversationSettings}">
    {#if !isPrivate}
      {#if isOperator || !$conversation.modes.topic_protection}
        <TextArea name="topic" form="{form}" placeholder="{$l('No topic is set.')}">
          <span slot="label">{$l('Topic')}</span>
        </TextArea>
      {:else}
        <div class="text-field">
          <label for="nothing">{$l('Topic')}</label>
          <div class="input">{@html $lmd(conversation.topic || 'No topic is set.')}</div>
        </div>
      {/if}
    {/if}

    {#if conversation.hasOwnProperty('wantNotifications')}
      <Checkbox name="want_notifications" form="{form}">
        <span slot="label">{$l('Notify me on new messages')}</span>
      </Checkbox>
    {/if}

    {#if !isPrivate}
      <nav class="sidebar-left__nav">
        <h3>{$l('Conversation modes')}</h3>
        {#each toggleModes as mode}
          <Checkbox badge name="mode_{mode}" form="{form}" disabled="{!isOperator}">
            <span slot="label">{$l(ucFirst(mode.replace(/_/g, ' ')))} <b class="badge">{$form['mode_' + mode] ? '+' : '-'}{getChannelMode(mode)}</b></span>
          </Checkbox>
          {#if mode == 'password' && $form.mode_password}
            <TextField type="password" name="password" form="{form}">
              <span slot="label">{$l('Password')}</span>
            </TextField>
          {/if}
        {/each}

        {#if !isOperator}
          <p><i>{$l('Only operators can change modes.')}</i></p>
        {/if}
      </nav>
    {/if}

    <div class="form-actions">
      <Button icon="save"><span>{$l('Update')}</span></Button>
      <Button type="button" on:click="{partConversation}" icon="sign-out-alt"><span>{$l('Leave')}</span></Button>
    </div>
    <OperationStatus op="{saveConversationSettingsOp}"/>
  </form>

  {#if !conversation.frozen && $viewport.nColumns < 3}
    <nav class="sidebar-left__nav">
      <h3>{$l('Participants (%1)', $participants.length)}</h3>
      {#each $participants.toArray() as participant}
        <Link href="/chat/{conversation.connection_id}/{participant.id}" class="participant {modeClassNames(participant.modes)}">
          <div>{participant.nick}</div>
        </Link>
      {/each}
    </nav>
  {/if}
</div>
