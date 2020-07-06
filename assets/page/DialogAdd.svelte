<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Link from '../components/Link.svelte';
import SelectField from '../components/form/SelectField.svelte';
import TextField from '../components/form/TextField.svelte';
import {debounce, extractErrorMessage} from '../js/util';
import {getContext, onMount} from 'svelte';
import {l} from '../js/i18n';
import {route} from '../store/Route';

const socket = getContext('socket');
const user = getContext('user');

let availableDialogs = {dialogs: [], done: null, n_dialogs: 0};
let connectionId = '';
let dialogId = '';
let formEl;
let loadConversationsTid;

$: connectionOptions = Array.from($user.connections.keys()).map(id => [id]);
$: if (!connectionId) connectionId = connectionOptions[0] ? connectionOptions[0][0] : '';

route.update({title: l('Add conversation')});
onMount(() => route.urlToForm(formEl));

function addDialog(e) {
  const aEl = e && e.target && e.target.closest('a');
  if (aEl && aEl.href) dialogId = aEl.href.replace(/.*#add:/, '');
  if (connectionId && dialogId) user.findDialog({connection_id: connectionId}).send('/join ' + dialogId);
}

async function loadConversations(e) {
  let message = '/list' + (dialogId.length ? ' /' + dialogId + '/' : '');
  if (e.type == 'click' && availableDialogs.done) message += ' refresh';
  if (loadConversationsTid) clearTimeout(loadConversationsTid);

  const res = await socket({connection_id: connectionId, message, method: 'send'});
  const error = extractErrorMessage(res);
  availableDialogs = error ? {dialogs: [], done: true, n_dialogs: 0, error} : res;

  let interval = e.interval ? e.interval + 500 : 500;
  if (interval > 2000) interval = 2000;
  if (!error && !res.done) loadConversationsTid = setTimeout(() => loadConversations({interval}), interval);
}

const debouncedLoadConversations = debounce(loadConversations, 250);
</script>

<ChatHeader>
  <h1>{l('Add conversation')}</h1>
</ChatHeader>

<main class="main">
  <p>
    {l('Enter the name of an exising conversation, or create a new conversation.')}
    {l('It is also possible to load in all existing conversations for a given connection.')}
  </p>

  <form method="post" bind:this="{formEl}" on:submit|preventDefault="{addDialog}">
    <div class="inputs-side-by-side">
      <SelectField name="connection_id" options="{connectionOptions}" placeholder="{l('Select...')}" bind:value="{connectionId}">
        <span slot="label">{l('Connection')}</span>
      </SelectField>
      <div class="has-remaining-space">
        <Button type="button" icon="sync-alt" on:click="{loadConversations}" disabled="{!connectionId || availableDialogs.done === false}"><span>{l(availableDialogs.dialogs.length ? 'Refresh' : 'Load')}</span></Button>
      </div>
    </div>

    <div class="inputs-side-by-side">
      <TextField name="dialog_id" placeholder="{l('#room or nick')}" autocomplete="off"
        bind:value="{dialogId}"
        on:keyup="{debouncedLoadConversations}">
        <span slot="label">{l('Conversation name')}</span>
      </TextField>
      <div class="has-remaining-space">
        <Button icon="comment" disabled="{!connectionId || !dialogId}"><span>{l('Add')}</span></Button>
      </div>
    </div>

    {#if availableDialogs.error}
      <p class="error">{connectionId}: {availableDialogs.error}</p>
    {/if}

    {#if availableDialogs.done !== null}
      <p>
        {#if availableDialogs.done}
          {l('Showing %1 of %2 conversations.', availableDialogs.dialogs.length, availableDialogs.n_dialogs)}
        {:else}
          {l('Showing %1 of %2 conversations, but the list is still loading.', availableDialogs.dialogs.length, availableDialogs.n_dialogs)}
        {/if}
      </p>

      <div class="dialog-add-list">
        {#each availableDialogs.dialogs as dialog}
          <a href="#add:{dialog.name}" on:click|preventDefault="{addDialog}">
            <span class="dialog-add-list__n-users">{dialog.n_users}</span>
            <b class="dialog-add-list__name">{dialog.name}</b>
            <i class="dialog-add-list__title">{dialog.topic || 'No topic.'}</i>
          </a>
        {/each}
      </div>
    {/if}
</form>
</main>
