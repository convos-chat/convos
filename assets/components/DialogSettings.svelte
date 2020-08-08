<script>
import Button from './form/Button.svelte';
import Checkbox from './form/Checkbox.svelte';
import Link from './Link.svelte';
import SettingsHeader from '../components/SettingsHeader.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {fly} from 'svelte/transition';
import {getContext} from 'svelte';
import {l, lmd} from '../js/i18n';
import {modeClassNames} from '../js/util';

export let dialog;
export let transition;

const socket = getContext('socket');
const user = getContext('user');

let dialogPassword = '';
let dialogTopic = dialog.topic;
let formEl;
let wantNotifications = dialog.wantNotifications;

$: isOperator = calculateIsOperator(dialog);
$: dialog.update({wantNotifications});
$: if (formEl && formEl.topic) formEl.topic.value = dialog.topic || '';

function calculateIsOperator(dialog) {
  const connection = user.findDialog({connection_id: dialog.connection_id});
  const participant = dialog.findParticipant(connection && connection.nick);
  return participant && participant.modes.operator;
}

function partDialog(e) {
  dialog.send('/part');
}

function saveDialogSettings(e) {
  if (dialogPassword) {
    dialog.send(isOperator ? '/mode +k ' + dialogPassword : '/join ' + dialog.name + ' ' + dialogPassword);
    dialogPassword = '';
  }

  if (isOperator && dialogTopic != dialog.topic) {
    dialog.send('/topic ' + dialogTopic);
  }
}
</script>

<div class="sidebar-left" transition:fly="{transition}">
  <SettingsHeader dialog="{dialog}"/>

  <p>
    {#if dialog.frozen}
      {l('Conversation with %1 is frozen. Reason: %2', dialog.name, l(dialog.frozen))}
    {:else if dialog.is('private')}
      {l('Private conversation with %1.', dialog.name)}
    {:else if isOperator}
      {l('You are channel operator in %1.', dialog.name)}
    {:else}
      {l('You are not a channel operator in %1.', dialog.name)}
    {/if}
  </p>

  <form method="post" on:submit|preventDefault="{saveDialogSettings}" bind:this="{formEl}">
    {#if !dialog.is('private')}
      <input type="hidden" name="connection_id" value="{dialog.connection_id}">
      <input type="hidden" name="dialog_id" value="{dialog.dialog_id}">

      {#if isOperator}
        <TextArea name="topic" placeholder="{l('No topic is set.')}" bind:value="{dialogTopic}">
          <span slot="label">{l('Topic')}</span>
        </TextArea>
      {:else}
        <div class="text-field">
          <label>{l('Topic')}</label>
          <div class="input">{@html lmd(dialogTopic || 'No topic is set.')}</div>
        </div>
      {/if}

      <TextField type="password" name="password" bind:value="{dialogPassword}" readonly="{!dialog.is('locked') && !isOperator}">
        <span slot="label">{l('Password')}</span>
      </TextField>

      {#if dialog.hasOwnProperty('wantNotifications')}
        <Checkbox bind:checked="{wantNotifications}">
          <span slot="label">{l('Send me notifications')}</span>
        </Checkbox>
      {/if}
    {/if}

    <div class="form-actions">
      {#if !dialog.is('private')}
        <Button icon="save"><span>{l('Update')}</span></Button>
      {/if}
      <Button type="button" on:click="{partDialog}" icon="sign-out-alt"><span>{l('Leave')}</span></Button>
    </div>
  </form>

  {#if !dialog.frozen}
    <nav class="sidebar-left__nav">
      <h3>{l('Participants (%1)', dialog.participants().length)}</h3>
      {#each dialog.participants() as participant}
        <Link href="/chat/{dialog.connection_id}/{participant.id}" class="participant {modeClassNames(participant.modes)}">
          <span>{participant.nick}</span>
        </Link>
      {/each}
    </nav>
  {/if}
</div>
