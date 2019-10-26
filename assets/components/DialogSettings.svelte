<script>
import Button from './form/Button.svelte';
import Link from './Link.svelte';
import SettingsHeader from '../components/SettingsHeader.svelte';
import TextArea from '../components/form/TextArea.svelte';
import {container} from '../store/router';
import {fly} from 'svelte/transition';
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import {modeClassNames} from '../js/util';

export let dialog = {};

const user = getContext('user');

let formEl;

$: isOperator = calculateIsOperator(dialog);
$: flyTransitionParameters = {duration: 250, x: $container.small ? $container.width : 0};
$: if (formEl && formEl.topic) formEl.topic.value = dialog.topic || '';

function calculateIsOperator(dialog) {
  const connection = user.findDialog({connection_id: dialog.connection_id});
  const currentNickId = (connection && connection.nick || '').toLowerCase();
  const participant = dialog.participants.get(currentNickId);
  return participant && participant.mode.indexOf('o') != -1;
}

function partDialog(e) {
  user.send({message: '/part', dialog});
}

function updateDialogFromForm(e) {
  user.send({message: '/topic ' + formEl.topic.value, dialog});
}
</script>

<div class="sidebar-left" transition:fly="{flyTransitionParameters}">
  <SettingsHeader dialog="{dialog}"/>

  <p>
    {#if dialog.is('private')}
      {l('Private conversation with %1.', dialog.name)}
    {:else if isOperator}
      {l('You are a channel operator in %1.', dialog.name)}
    {:else}
      {l('You are not a channel operator in %1.', dialog.name)}
    {/if}
  </p>

  <form method="post" on:submit|preventDefault="{updateDialogFromForm}" bind:this="{formEl}">
    {#if !dialog.is('private')}
      <input type="hidden" name="connection_id" value="{dialog.connection_id}">
      <input type="hidden" name="dialog_id" value="{dialog.dialog_id}">
      <TextArea name="topic" placeholder="{l('No topic is set.')}" readonly="{!isOperator}">
        <span slot="label">{l('Topic')}</span>
      </TextArea>
    {/if}
    <div class="form-actions">
      {#if !dialog.is('private')}
        <Button icon="save" disabled="{!isOperator}">{l('Update')}</Button>
      {/if}
      <Button type="button" on:click="{partDialog}" icon="sign-out-alt">{l('Part')}</Button>
    </div>
  </form>

  <nav class="sidebar-left__nav">
    <h3>{l('Participants (%1)', dialog.participants.size)}</h3>
    {#each dialog.participants.toArray() as participant}
      <Link href="/chat/{dialog.connection_id}/{participant.id}" class="participant {modeClassNames(participant.mode)}">
        <span>{participant.nick}</span>
      </Link>
    {/each}
  </nav>
</div>
