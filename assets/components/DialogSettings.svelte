<script>
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import Button from '../components/form/Button.svelte';
import Link from '../components/Link.svelte';
import SettingsHeader from '../components/SettingsHeader.svelte';
import TextArea from '../components/form/TextArea.svelte';

export let dialog = {};

const user = getContext('user');

let formEl;

$: participants = $dialog.findParticipants();
$: if (formEl && formEl.topic) formEl.topic.value = dialog.topic || '';

function partDialog(e) {
  user.send({message: '/part', dialog});
}

function updateDialogFromForm(e) {
  user.send({message: '/topic ' + formEl.topic.value, dialog});
}
</script>

<div class="sidebar-wrapper is-visible">
  <SettingsHeader {dialog}/>

  <p>
    {#if dialog.is('private')}
      {l('Private conversation with %1.', dialog.name)}
    {:else if user.isDialogOperator(dialog)}
      {l('You are a channel operator in %1.', dialog.name)}
    {:else}
      {l('You are not a channel operator in %1.', dialog.name)}
    {/if}
  </p>

  <form method="post" bind:this="{formEl}" on:submit|preventDefault="{updateDialogFromForm}">
    {#if !dialog.is('private')}
      <input type="hidden" name="connection_id" value="{dialog.connection_id}">
      <input type="hidden" name="dialog_id" value="{dialog.dialog_id}">
      <TextArea name="topic" placeholder="{l('No topic is set.')}" readonly="{!user.isDialogOperator(dialog)}">
        <span slot="label">{l('Topic')}</span>
      </TextArea>
    {/if}
    <div class="form-actions">
      {#if !dialog.is('private')}
        <Button icon="save" disabled="{!user.isDialogOperator(dialog)}">{l('Update')}</Button>
      {/if}
      <Button type="button" on:click|preventDefault="{partDialog}" icon="sign-out-alt">{l('Part')}</Button>
    </div>
  </form>

  <nav class="sidebar__nav">
    <h3>{l('Participants (%1)', participants.length)}</h3>
    {#if participants.length}
      {#each participants as participant}
        <Link href="/chat/{dialog.connection_id}/{participant.id}">{participant.mode}{participant.nick}</Link>
      {/each}
    {:else}
      <p>{l('No participants.')}</p>
    {/if}
  </nav>
</div>
