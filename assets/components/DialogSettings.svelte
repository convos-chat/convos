<script>
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import DialogSubject from '../components/DialogSubject.svelte';
import FormActions from '../components/form/FormActions.svelte';
import StateIcon from '../components/StateIcon.svelte';

export let connectionId;
export let dialogId;

const user = getContext('user');

async function partDialog(e) {
  alert('TODO');
}

$: dialog = $user.dialogs.filter(d => d.connection_id == connectionId && d.dialog_id == dialogId)[0] || {};
</script>

<div class="settings-pane">
  <h2>{l('Dialog info')}</h2>
  <p>
    {#if dialog.frozen}
      <StateIcon obj="{dialog}"/>
    {/if}
    <DialogSubject obj="{dialog}"/>
  </p>
  <FormActions>
    <a href="#close" class="btn" on:click|preventDefault="{partDialog}">{l('Close conversation')}</a>
  </FormActions>
</div>