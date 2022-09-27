<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import SelectField from '../components/form/SelectField.svelte';
import TextField from '../components/form/TextField.svelte';
import debounce from 'lodash/debounce';
import {extractErrorMessage} from '../js/util';
import {getContext} from 'svelte';
import {l} from '../store/I18N';
import {route} from '../store/Route';

export const title = 'Add conversation';

const socket = getContext('socket');
const user = getContext('user');

let availableConversations = {conversations: [], done: null, n_conversations: 0};
let connectionId = '';
let conversationId = '';
let loadConversationsTid;

$: connectionOptions = Array.from($user.connections.keys()).map(id => [id]);
$: if (!connectionId) renderForm();

function addConversation(e) {
  const aEl = e && e.target && e.target.closest('a');
  if (aEl && aEl.href) conversationId = aEl.href.replace(/.*#add:/, '');
  const connection = user.findConversation({connection_id: connectionId});
  if (connection && conversationId) connection.send('/join ' + conversationId);
}

async function loadConversations(e) {
  let message = '/list' + (conversationId.length ? ' /' + conversationId + '/' : '');
  if (e.type === 'click' && availableConversations.done) message += ' refresh';
  if (loadConversationsTid) clearTimeout(loadConversationsTid);

  socket.send({connection_id: connectionId, message, method: 'send'}, (res) => {
    const error = extractErrorMessage(res);
    availableConversations = error ? {conversations: [], done: true, n_conversations: 0, error} : res;

    let interval = e.interval ? e.interval + 500 : 500;
    if (interval > 2000) interval = 2000;
    if (!error && !res.done) loadConversationsTid = setTimeout(() => loadConversations({interval}), interval);
  });
}

function renderForm() {
  connectionId = route.param('connection_id') || connectionOptions[0][0] || '';
  conversationId = route.param('conversation_id') || '';
}

const debouncedLoadConversations = debounce(loadConversations, 250);
</script>

<ChatHeader>
  <h1>{$l('Add conversation')}</h1>
</ChatHeader>

<main class="main">
  <p>{$l('Enter the name of an exising conversation, or create a new conversation.')}</p>

  <form method="post" on:submit|preventDefault="{addConversation}">
    <div class="inputs-side-by-side">
      <SelectField name="connection_id" bind:value="{connectionId}" options="{connectionOptions}" placeholder="{$l('Select...')}">
        <span slot="label">{$l('Connection')}</span>
      </SelectField>
      <div class="flex-basis-30">
        <Button type="button" icon="sync-alt" on:click="{loadConversations}" disabled="{!connectionId || availableConversations.done === false}"><span>{$l(availableConversations.conversations.length ? 'Refresh' : 'Load')}</span></Button>
      </div>
    </div>

    <div class="inputs-side-by-side">
      <TextField name="conversation_id" bind:value="{conversationId}" placeholder="{$l('#room or nick')}" autocomplete="off" on:keyup="{debouncedLoadConversations}">
        <span slot="label">{$l('Conversation name')}</span>
      </TextField>
      <div class="flex-basis-30">
        <Button icon="comment" disabled="{!connectionId || !conversationId}"><span>{$l('Add')}</span></Button>
      </div>
    </div>

    {#if availableConversations.error}
      <p class="error">{connectionId}: {availableConversations.error}</p>
    {/if}

    {#if availableConversations.done !== null}
      <p>
        {#if availableConversations.done}
          {$l('Showing %1 of %2 conversations.', availableConversations.conversations.length, availableConversations.n_conversations)}
        {:else}
          {$l('Showing %1 of %2 conversations, but the list is still loading.', availableConversations.conversations.length, availableConversations.n_conversations)}
        {/if}
      </p>

      <div class="conversation-add-list">
        {#each availableConversations.conversations as conversation}
          <a href="#add:{conversation.name}" on:click|preventDefault="{addConversation}">
            <span class="conversation-add-list__n-users">{conversation.n_users}</span>
            <b class="conversation-add-list__name">{conversation.name}</b>
            <i class="conversation-add-list__title">{conversation.topic || 'No topic.'}</i>
          </a>
        {/each}
      </div>
    {/if}
  </form>
</main>
