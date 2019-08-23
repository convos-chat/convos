<script>
import {l} from '../js/i18n';
import {getContext, onMount, tick} from 'svelte';
import {md} from '../js/md';
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import FormActions from '../components/form/FormActions.svelte';
import Link from '../components/Link.svelte';
import SelectField from '../components/form/SelectField.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import TextField from '../components/form/TextField.svelte';

const user = getContext('user');
const dialogs = [];

let connection_id = '';
let formEl;

$: connectionOptions = $user.connections.map(c => [c.connection_id]);

function joinDialog(e) {
  console.log('TODO: joinDialog()');
}

function loadConversations() {
  console.log('TODO: loadConversations()');
}
</script>

<SidebarChat/>

<main class="main join-conversation-container">
  <ChatHeader>
    <h1>{l('Add conversation')}</h1>
  </ChatHeader>

  <p>{l('Enter the name of a dialog to either search for the known dialogs, or to create a new chat room.')}</p>

  <form method="post" bind:this="{formEl}" on:submit|preventDefault="{joinDialog}">
    <SelectField options="{connectionOptions}" placeholder="{l('Select...')}" bind:value="{connection_id}">
      <span slot="label">{l('Connection')}</span>
    </SelectField>
    <div class="inputs-side-by-side">
      <TextField name="conversation_name" placeholder="{l('#room or nick')}">
        <span slot="label">{l('Conversation name')}</span>
      </TextField>
      <Button icon="comment">{l('Add')}</Button>
    </div>
    <div class="dialogs">
      {#each dialogs as dialog}
        <div class="dialogs_dialog">
          <h3>{dialog.name}</h3>
        </div>
      {/each}
    </div>
    <FormActions>
      <Button type="button" icon="sync-alt" on:click|preventDefault="{loadConversations}" disabled="{!connection_id}">{l('Load conversations')}</Button>
    </FormActions>
</form>
</main>
