<script>
import {l} from '../js/i18n';
import {getContext, onMount} from 'svelte';
import {md} from '../js/md';
import {urlToForm} from '../store/router';
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Link from '../components/Link.svelte';
import SelectField from '../components/form/SelectField.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import TextField from '../components/form/TextField.svelte';

const user = getContext('user');
const dialogs = [];

let connectionId = '';
let dialogId = '';
let formEl;

$: connectionOptions = $user.connections.map(c => [c.connection_id]);

function joinDialog(e) {
  if (!connectionId || !dialogId) return;
  user.send({
    connection_id: connectionId,
    method: 'send',
    message: dialogId.match(/^[a-z]/i) ? `/query ${dialogId}` : `/join ${dialogId}`,
    source: 'conversation-add',
  });
}

function loadConversations() {
  console.log('TODO: loadConversations()');
}

onMount(() => urlToForm(formEl));
</script>

<SidebarChat/>

<main class="main join-conversation-container">
  <ChatHeader>
    <h1>{l('Add conversation')}</h1>
  </ChatHeader>

  <p>
    {l('Enter the name of an exising conversation, or create a new conversation.')}
    {l('It is also possible to load in all existing conversations for a given connection.')}
  </p>

  <form method="post" bind:this="{formEl}" on:submit|preventDefault="{joinDialog}">
    <div class="inputs-side-by-side">
      <SelectField name="connection_id" options="{connectionOptions}" placeholder="{l('Select...')}" bind:value="{connectionId}">
        <span slot="label">{l('Connection')}</span>
      </SelectField>
      <Button type="button" icon="sync-alt" on:click|preventDefault="{loadConversations}" disabled="{!connectionId}">{l(dialogs.length ? 'Refresh' : 'Load')}</Button>
    </div>
    <div class="inputs-side-by-side">
      <TextField name="dialog_id" bind:value="{dialogId}" placeholder="{l('#room or nick')}">
        <span slot="label">{l('Conversation name')}</span>
      </TextField>
      <Button icon="comment" disabled="{!connectionId || !dialogId}">{l('Add')}</Button>
    </div>
    <div class="dialogs">
      {#each dialogs as dialog}
        <a href="#join:{dialog.name}" on:click|preventDefault="{joinDialog}">
          <span class="dialogs__dialog__n-users">{dialog.n_users}</span>
          <b class="dialogs__dialog__name">{dialog.name}</b>
          <i class="dialogs__dialog__title">{dialog.topic}</i>
        </a>
      {/each}
    </div>
</form>
</main>
