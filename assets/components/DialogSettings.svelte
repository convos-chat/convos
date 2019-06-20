<script>
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import DialogSubject from '../components/DialogSubject.svelte';
import FormActions from '../components/form/FormActions.svelte';
import StateIcon from '../components/StateIcon.svelte';

export let dialog = {};

const user = getContext('user');

async function partDialog(e) {
  alert('TODO');
}
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
    <a href="#close" class="btn" on:click|preventDefault="{partDialog}">{l('Part conversation')}</a>
  </FormActions>
</div>
