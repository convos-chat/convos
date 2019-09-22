<script>
import {debounce, extractErrorMessage} from '../js/util';
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

let availableDialogs = {dialogs: [], done: null, n_dialogs: 0};
let connectionId = '';
let dialogId = '';
let formEl;

const debouncedLoadConversations = debounce(loadConversations, 250);

$: connectionOptions = $user.connections.map(c => [c.connection_id]);
$: if (!connectionId) connectionId = connectionOptions[0] ? connectionOptions[0][0] : '';

function joinDialog(e) {
  const aEl = e && e.target && e.target.closest('a');
  if (aEl && aEl.href) dialogId = aEl.href.replace(/.*#join:/, '');
  if (!connectionId || !dialogId) return;
  const message = dialogId.match(/^[a-z]/i) ? `/query ${dialogId}` : `/join ${dialogId}`;
  user.send({connection_id: connectionId, message});
}

function loadConversations(e) {
  let message = '/list';

  if (e) {
    message += dialogId.length ? ' /' + dialogId + '/' : '';
  }
  else if (availableDialogs.dialogs.length) {
    message += ' refresh';
  }

  user.send({connection_id: connectionId, message}, (params) => {
    const error = extractErrorMessage(params);
    availableDialogs = error ? {dialogs: [], done: null, n_dialogs: 0, error} : params;
    if (!error && !params.done) setTimeout(loadConversations, 500);
  });
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
      <Button type="button" icon="sync-alt" on:click|preventDefault="{loadConversations}" disabled="{!connectionId}">{l(availableDialogs.dialogs.length ? 'Refresh' : 'Load')}</Button>
    </div>

    <div class="inputs-side-by-side">
      <TextField name="dialog_id" placeholder="{l('#room or nick')}" autocomplete="off"
        bind:value="{dialogId}"
        on:keyup="{debouncedLoadConversations}">
        <span slot="label">{l('Conversation name')}</span>
      </TextField>
      <Button icon="comment" disabled="{!connectionId || !dialogId}">{l('Add')}</Button>
    </div>

    {#if availableDialogs.error}
      <p class="error">{connectionId}: {availableDialogs.error}</p>
    {/if}

    {#if availableDialogs.done !== null}
      <p>
        {#if availableDialogs.done}
          {l('Showing %1 of %2 dialogs.', availableDialogs.dialogs.length, availableDialogs.n_dialogs)}
        {:else}
          {l('Showing %1 of %2 dialogs, but dialogs are still loading.', availableDialogs.dialogs.length, availableDialogs.n_dialogs)}
        {/if}
      </p>

      <div class="dialog-list">
        {#each availableDialogs.dialogs as dialog}
          <a href="#join:{dialog.name}" on:click|preventDefault="{joinDialog}">
            <span class="dialog-list__n-users">{dialog.n_users}</span>
            <b class="dialog-list__name">{dialog.name}</b>
            <i class="dialog-list__title">{dialog.topic || 'No topic.'}</i>
          </a>
        {/each}
      </div>
    {/if}
</form>
</main>
