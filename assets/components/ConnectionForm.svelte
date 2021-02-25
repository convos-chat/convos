<script>
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import Connection from '../store/Connection';
import ConnectionURL from '../js/ConnectionURL';
import OperationStatus from '../components/OperationStatus.svelte';
import SelectField from '../components/form/SelectField.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {formAction, makeFormStore} from '../store/form';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../store/I18N';
import {route} from '../store/Route';

export let conversation = {};

const api = getContext('api');
const form = makeFormStore({});
const user = getContext('user');
const saslMechanisms = [['none', 'None'], ['plain', 'Plain'], ['external', 'External']];

const createConnectionOp = api('createConnection');
const removeConnectionOp = api('removeConnection');
const updateConnectionOp = api('updateConnection');

let connection = {};
let showAdvancedSettings = false;

$: showAdvancedSettings && form.renderOnNextTick();

onMount(async () => {
  connection = user.findConversation({connection_id: conversation.connection_id}) || {};
  if (connection.toForm) form.render(connection.toForm());
  if (!connection.connection_id) form.render(defaultConnectinFormFields());

  form.submit = async () => {
    if (connection.connection_id) {
      await updateConnectionOp.perform(connection.toSaveOperationParams($form));
      connection = user.ensureConversation(updateConnectionOp.res.body);
      form.render(connection.toForm());
    }
    else {
      await createConnectionOp.perform(new Connection({}).toSaveOperationParams($form));
      const body = createConnectionOp.res.body;
      if (body.connection_id) route.go(user.ensureConversation(body).path);
    }
  };
});

function defaultConnectinFormFields() {
  const url = new ConnectionURL(route.query.uri || user.default_connection || '');
  const fields = {
    nick: user.email.replace(/@.*/, '').replace(/\W/g, '_'),
    sasl: 'none',
    server: '',
    wanted_state: 'connected',
   };

  if (route.query.uri || user.forced_connection) {
    fields.conversation_id = decodeURIComponent(url.pathname.split('/').filter(p => p.length)[0] || '');
    fields.password = url.password,
    fields.server = url.host;
    fields.sasl = url.searchParams.get('sasl') || 'none';
    fields.tls = url.searchParams.get('tls') ? true : false;
    fields.tls_verify = url.searchParams.get('tls_verify') ? true : false;
    fields.username = url.username;
    fields.username = url.username;
  }

  return fields;
}

async function removeConnection(e) {
  await removeConnectionOp.perform(connection);
  user.removeConversation(connection);
  route.go('/settings/connection');
}
</script>

<form method="post" use:formAction="{form}">
  <input type="hidden" name="url">

  <TextField name="server" placeholder="{$l('Ex: chat.freenode.net:6697')}" readonly="{user.forced_connection}">
    <span slot="label">{$l('Host and port')}</span>
    <p class="help" slot="help">
      {@html $lmd(user.forced_connection ? 'You cannot create custom connections.' : 'Example: %1', 'chat.freenode.net:6697')}
    </p>
  </TextField>

  <TextField name="nick" placeholder="{$l('Ex: superman')}">
    <span slot="label">{$l('Nickname')}</span>
  </TextField>

  <TextField name="realname" placeholder="{$l('Ex: Clark Kent')}">
    <span slot="label">{$l('Your name')}</span>
    <p class="help" slot="help">Visible in WHOIS response</p>
  </TextField>

  {#if connection.connection_id}
    <Checkbox name="wanted_state">
      <span slot="label">{$l('Want to be connected')}</span>
    </Checkbox>
  {:else}
    <TextField name="conversation_id" placeholder="{$l('Ex: #convos')}">
      <span slot="label">{$l('Conversation name')}</span>
    </TextField>
  {/if}

  <Checkbox name="tls">
    <span slot="label">{$l('Secure connection (TLS)')}</span>
  </Checkbox>
  <Checkbox name="tls_verify" disabled="{!$form.tls}" hidden="{!$form.tls}">
    <span slot="label">{$l('Verify certificate (TLS)')}</span>
  </Checkbox>

  <Checkbox bind:checked="{showAdvancedSettings}">
    <span slot="label">{$l('Show advanced settings')}</span>
  </Checkbox>
  {#if showAdvancedSettings}
    <TextField name="username">
      <span slot="label">{$l('Username')}</span>
    </TextField>
    <TextField type="password" name="password">
      <span slot="label">{$l('Password')}</span>
    </TextField>
    <SelectField name="sasl" options="{saslMechanisms}">
      <span slot="label">{$l('SASL authentication mechanism')}</span>
    </SelectField>
    <TextArea name="on_connect_commands" placeholder="{$l('Put each command on a new line.')}">
      <span slot="label">{$l('On-connect commands')}</span>
    </TextArea>
    <TextField name="local_address">
      <span slot="label">{$l('Source IP')}</span>
      <p class="help" slot="help">{$l('Leave this blank, unless you know what you are doing.')}</p>
    </TextField>
  {/if}

  <div class="form-actions">
    {#if connection.connection_id}
      <Button icon="save" op="{updateConnectionOp}"><span>{$l('Update')}</span></Button>
      <Button icon="trash" type="button" op="{removeConnectionOp}" on:click="{removeConnection}"><span>{$l('Delete')}</span></Button>
    {:else}
      <Button icon="save" op="{createConnectionOp}"><span>{$l('Create')}</span></Button>
    {/if}
  </div>
  <OperationStatus op="{createConnectionOp}"/>
  <OperationStatus op="{removeConnectionOp}"/>
  <OperationStatus op="{updateConnectionOp}"/>
</form>
