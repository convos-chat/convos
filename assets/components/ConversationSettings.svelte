<script>
import Button from './form/Button.svelte';
import Checkbox from './form/Checkbox.svelte';
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {activeMenu, nColumns} from '../store/writable';
import {fly} from 'svelte/transition';
import {getContext} from 'svelte';
import {l, lmd} from '../store/I18N';
import {modeClassNames} from '../js/util';

export let conversation;
export let transition;

const user = getContext('user');

let conversationPassword = '';
let conversationTopic = conversation.topic;
let formEl;
let wantNotifications = conversation.wantNotifications;

$: isOperator = calculateIsOperator(conversation);
$: conversation.update({wantNotifications});
$: participants = conversation.participants;
$: if (formEl && formEl.topic) formEl.topic.value = conversation.topic || '';

function calculateIsOperator(conversation) {
  const connection = user.findConversation({connection_id: conversation.connection_id});
  const participant = conversation.participants.get(connection && connection.nick);
  return participant && participant.modes.operator;
}

function partConversation(e) {
  conversation.send('/part', (res) => !res.errrors && ($activeMenu = ''));
}

function saveConversationSettings(e) {
  if (conversationPassword) {
    conversation.send(isOperator ? '/mode +k ' + conversationPassword : '/join ' + conversation.name + ' ' + conversationPassword);
    conversationPassword = '';
  }

  if (isOperator && conversationTopic != conversation.topic) {
    conversation.send('/topic ' + conversationTopic);
  }
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
    {:else if conversation.is('private')}
      {$l('Private conversation with %1.', conversation.name)}
    {:else if isOperator}
      {$l('You are channel operator in %1.', conversation.name)}
    {:else}
      {$l('You are not a channel operator in %1.', conversation.name)}
    {/if}
  </p>

  <form method="post" on:submit|preventDefault="{saveConversationSettings}" bind:this="{formEl}">
    {#if !conversation.is('private')}
      <input type="hidden" name="connection_id" value="{conversation.connection_id}">
      <input type="hidden" name="conversation_id" value="{conversation.conversation_id}">

      {#if isOperator}
        <TextArea name="topic" placeholder="{$l('No topic is set.')}" bind:value="{conversationTopic}">
          <span slot="label">{$l('Topic')}</span>
        </TextArea>
      {:else}
        <div class="text-field">
          <label for="nothing">{$l('Topic')}</label>
          <div class="input">{@html $lmd(conversationTopic || 'No topic is set.')}</div>
        </div>
      {/if}

      <TextField type="password" name="password" bind:value="{conversationPassword}" readonly="{!conversation.is('locked') && !isOperator}">
        <span slot="label">{$l('Password')}</span>
      </TextField>
    {/if}

    {#if conversation.hasOwnProperty('wantNotifications')}
      <Checkbox bind:checked="{wantNotifications}">
        <span slot="label">{$l('Notify me on new messages')}</span>
      </Checkbox>
    {/if}

    <div class="form-actions">
      {#if !conversation.is('private')}
        <Button icon="save"><span>{$l('Update')}</span></Button>
      {/if}
      <Button type="button" on:click="{partConversation}" icon="sign-out-alt"><span>{$l('Leave')}</span></Button>
    </div>
  </form>

  {#if !conversation.frozen && $nColumns < 3}
    <nav class="sidebar-left__nav">
      <h3>{$l('Participants (%1)', $participants.length)}</h3>
      {#each $participants.toArray() as participant}
        <Link href="/chat/{conversation.connection_id}/{participant.id}" class="participant {modeClassNames(participant.modes)}">
          <span>{participant.nick}</span>
        </Link>
      {/each}
    </nav>
  {/if}
</div>
