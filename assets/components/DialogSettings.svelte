<script>
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import Button from '../components/Button.svelte';
import FormActions from '../components/form/FormActions.svelte';
import SettingsHeader from '../components/SettingsHeader.svelte';
import TextArea from '../components/form/TextArea.svelte';

export let dialog = {};

const user = getContext('user');

let formEl;

async function partDialog(e) {
  user.send({message: '/part', method: 'send', dialog});
}

async function updateDialogFromForm(e) {
  user.send({message: '/topic ' + formEl.topic.value, method: 'send', dialog});
}
</script>

<div class="sidebar-wrapper is-visible">
  <SettingsHeader {dialog}/>

  <p>
    {#if dialog.is_private}
      {l('Private conversation with %1.', dialog.name)}
    {:else if user.isDialogOperator(dialog)}
      {l('You are a channel operator in %1.', dialog.name)}
    {:else}
      {l('You are not a channel operator in %1.', dialog.name)}
    {/if}
  </p>

  <form method="post" bind:this="{formEl}" on:submit|preventDefault="{updateDialogFromForm}">
    {#if !dialog.is_private}
      <input type="hidden" name="connection_id" value="{dialog.connection_id}">
      <input type="hidden" name="dialog_id" value="{dialog.dialog_id}">
      <TextArea name="topic" placeholder="{l('No topic is set.')}" readonly="{!user.isDialogOperator(dialog)}">
        <span slot="label">{l('Topic')}</span>
      </TextArea>
    {/if}
    <FormActions>
      {#if !dialog.is_private}
        <Button icon="save" disabled="{!user.isDialogOperator(dialog)}">{l('Update')}</Button>
      {/if}
      <Button icon="sign-out-alt" on:click|preventDefault="{partDialog}">{l('Part')}</Button>
    </FormActions>
  </form>
</div>
