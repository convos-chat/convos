<script>
import Button from './form/Button.svelte';
import Checkbox from './form/Checkbox.svelte';
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {activeMenu, viewport} from '../store/writable';
import {createForm} from '../store/form';
import {fly} from 'svelte/transition';
import {getContext, onMount, tick} from 'svelte';
import {l, lmd} from '../store/I18N';
import {modeClassNames, ucFirst} from '../js/util';

export let conversation;
export let transition;

const form = createForm({password: ''});
const user = getContext('user');

$: isOperator = $conversation.participants.me().modes.operator;
$: participants = $conversation.participants;
$: modes = Object.keys($conversation.modes).sort().filter(k => conversation.modes[k]);

onMount(async () => {
  form.set({topic: conversation.topic, want_notifications: conversation.wantNotifications});
  await new Promise(r => conversation.send('/mode', r));
  await tick();
  form.set({password_protected: conversation.modes.password || false});
});

function partConversation() {
  conversation.send('/part', (res) => !res.errrors && ($activeMenu = ''));
}

function saveConversationSettings() {
  conversation.update({wantNotifications: form.get('want_notifications') || false});

  if (isOperator && !form.get('password_protected')) {
    if (conversation.modes.password) conversation.send('/mode -k');
  }
  else if (form.get('password') && form.get('password_protected')) {
    const password = form.get('password');
    conversation.send(isOperator ? '/mode +k ' + password : '/join ' + conversation.name + ' ' + password);
    form.set({password: ''});
  }

  if (isOperator && form.get('topic') != conversation.topic) {
    conversation.send('/topic ' + form.get('topic'));
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

  <form method="post" on:submit|preventDefault="{saveConversationSettings}">
    {#if !conversation.is('private')}
      {#if isOperator}
        <TextArea name="topic" form="{form}" placeholder="{$l('No topic is set.')}">
          <span slot="label">{$l('Topic')}</span>
        </TextArea>
        <Checkbox name="password_protected" form="{form}">
          <span slot="label">{$l('Protect conversation with a password')}</span>
        </Checkbox>
        {#if $form.password_protected}
          <TextField type="password" name="password" form="{form}">
            <span slot="label">{$l('Password')}</span>
          </TextField>
        {/if}
      {:else}
        <div class="text-field">
          <label for="nothing">{$l('Topic')}</label>
          <div class="input">{@html $lmd(conversation.topic || 'No topic is set.')}</div>
        </div>
        <TextField type="password" name="password" form="{form}" readonly="{!conversation.is('locked')}">
          <span slot="label">{$l('Password')}</span>
        </TextField>
      {/if}
    {/if}

    {#if conversation.hasOwnProperty('wantNotifications')}
      <Checkbox name="want_notifications" form="{form}">
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

  {#if modes.length}
    <nav class="sidebar-left__nav">
      <h3>{$l('Active modes')}</h3>
      {#each modes as mode}
        <div>{$l(ucFirst(mode.replace(/_/g, ' ')))}</div>
      {/each}
    </nav>
  {/if}

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
