<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Link from '../components/Link.svelte';
import SelectField from '../components/form/SelectField.svelte';
import TextField from '../components/form/TextField.svelte';
import {createForm} from '../store/form';
import {debounce, extractErrorMessage} from '../js/util';
import {getContext, onMount} from 'svelte';
import {l} from '../store/I18N';
import {route} from '../store/Route';

export const title = 'Add conversation';

const form = createForm();
const socket = getContext('socket');
const user = getContext('user');

let availableConversations = {conversations: [], done: null, n_conversations: 0};
let loadConversationsTid;

$: connectionOptions = Array.from($user.connections.keys()).map(id => [id]);
$: if (!$form.connection_id) renderForm();

function addConversation(e) {
  const aEl = e && e.target && e.target.closest('a');
  if (aEl && aEl.href) form.set({conversation_id: aEl.href.replace(/.*#add:/, '')});
  const connection = user.findConversation({connection_id: form.get('connection_id')});
  if (connection && form.get('conversation_id')) connection.send('/join ' + form.get('conversation_id'));
}

async function loadConversations(e) {
  const conversationId = form.get('conversation_id') || '';
  let message = '/list' + (conversationId.length ? ' /' + conversationId + '/' : '');
  if (e.type == 'click' && availableConversations.done) message += ' refresh';
  if (loadConversationsTid) clearTimeout(loadConversationsTid);

  const connectionId = form.get('connection_id');
  socket.send({connection_id: connectionId, message, method: 'send'}, (res) => {
    const error = extractErrorMessage(res);
    availableConversations = error ? {conversations: [], done: true, n_conversations: 0, error} : res;

    let interval = e.interval ? e.interval + 500 : 500;
    if (interval > 2000) interval = 2000;
    if (!error && !res.done) loadConversationsTid = setTimeout(() => loadConversations({interval}), interval);
  });
}

function renderForm() {
  form.set({
    connection_id: route.param('connection_id') || connectionOptions[0] || '',
    conversation_id: route.param('conversation_id') || '',
  });
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
      <SelectField name="connection_id" form="{form}" options="{connectionOptions}" placeholder="{$l('Select...')}">
        <span slot="label">{$l('Connection')}</span>
      </SelectField>
      <div class="flex-basis-30">
        <Button type="button" icon="sync-alt" on:click="{loadConversations}" disabled="{!$form.connection_id || availableConversations.done === false}"><span>{$l(availableConversations.conversations.length ? 'Refresh' : 'Load')}</span></Button>
      </div>
    </div>

    <div class="inputs-side-by-side">
      <TextField name="conversation_id" form="{form}" placeholder="{$l('#room or nick')}" autocomplete="off" on:keyup="{debouncedLoadConversations}">
        <span slot="label">{$l('Conversation name')}</span>
      </TextField>
      <div class="flex-basis-30">
        <Button icon="comment" disabled="{!$form.connection_id || !$form.conversation_id}"><span>{$l('Add')}</span></Button>
      </div>
    </div>

    {#if availableConversations.error}
      <p class="error">{$form.connection_id}: {availableConversations.error}</p>
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
