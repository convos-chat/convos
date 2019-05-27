<script>
import {dialogs} from '../store/user';
import {l} from '../js/i18n';
import {pathParts} from '../store/router';
import FormActions from '../components/form/FormActions.svelte';
import StateIcon from '../components/StateIcon.svelte';

export let connectionId;
export let dialogId;

function partDialog(e) {
  alert('TODO');
}

$: dialog = $dialogs.filter(d => d.connection_id == connectionId && d.dialog_id == dialogId)[0] || {};
</script>

<div class="settings-pane">
  <h2>{l('Dialog info')}</h2>

  {#if dialog.frozen}
    <p>
      <StateIcon obj="{dialog}"/>
      {l(dialog.frozen)}
    </p>
  {/if}

  <FormActions>
    <a href="#close" class="btn" on:click|preventDefault="{partDialog}">{l('Close converstaion')}</a>
  </FormActions>
</div>