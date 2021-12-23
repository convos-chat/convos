<script>
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import ConnectionURL from '../js/ConnectionURL';
import OperationStatus from '../components/OperationStatus.svelte';
import SelectField from '../components/form/SelectField.svelte';
import TextArea from '../components/form/TextArea.svelte';
import TextField from '../components/form/TextField.svelte';
import {createForm} from '../store/form';
import {getContext, onMount} from 'svelte';
import {is} from '../js/util';
import {l, lmd} from '../store/I18N';
import {route} from '../store/Route';
import {slide} from 'svelte/transition';

let connection_id = 'add';
export {connection_id as id};
export let is_page = false;

const api = getContext('api');
const form = createForm();
const user = getContext('user');
const saslMechanisms = [['none', 'None'], ['plain', 'Plain'], ['external', 'External']];

const createConnectionOp = api('createConnection');
const removeConnectionOp = api('removeConnection');
const updateConnectionOp = api('updateConnection');

let connection = {};

onMount(() => {
  connection = connection_id == 'add' ? {} : $user.findConversation({connection_id}) || {};
  connection.connection_id ? connectionToForm(connection) : defaultsToForm();
});

function connectionToForm(connection) {
  const fields = connection.url ? connection.url.toFields() : {};
  if (is.array(connection.on_connect_commands)) fields.on_connect_commands = connection.on_connect_commands.join('\n');
  if (!fields.nick) fields.nick = user.email.replace(/@.*/, '').replace(/\W/g, '_');
  fields.want_to_be_connected = connection.wanted_state == 'disconnected' ? false : true;
  form.set(fields);
  form.set({fingerprint: connection.certificate.fingerprint || ''});
}

function defaultsToForm() {
  const fields = new ConnectionURL(route.query.uri || user.default_connection || 'irc://localhost').toFields();
  fields.want_to_be_connected = true;
  if (user.connections.size && !route.query.uri) fields.host = '';
  if (!fields.nick) fields.nick = user.email.replace(/@.*/, '').replace(/\W/g, '_');
  form.set(fields);
}

async function removeConnection() {
  await removeConnectionOp.perform(connection);
  user.removeConversation(connection);
  route.go('/settings/connections');
}

async function saveConnection() {
  const params = form.get();
  params.on_connect_commands = (params.on_connect_commands || '').split(/\n\r?/).filter(i => i.length);
  params.url = new ConnectionURL('irc://localhost').fromFields(params).toString();

  if (connection.connection_id) {
    params.connection_id = connection.connection_id;
    params.wanted_state = params.want_to_be_connected ? 'connected' : 'disconnected';
    await updateConnectionOp.perform(params);
    connection = user.ensureConversation(updateConnectionOp.res.body);
    connectionToForm(connection);
  }
  else {
    await createConnectionOp.perform(params);
    const body = createConnectionOp.res.body;
    if (body.connection_id) route.go(user.ensureConversation(body).path);
  }

  if (is_page) route.go('/settings/connections');
}
</script>

<form method="post" on:submit|preventDefault="{saveConnection}">
  <TextField name="host" form="{form}" placeholder="{$l('Ex: irc.libera.chat:6697')}" readonly="{user.forced_connection}">
    <span slot="label">{$l('Host and port')}</span>
    <p class="help" slot="help" hidden="{!user.forced_connection}">{$l('You cannot create custom connections.')}</p>
  </TextField>
  <TextField name="nick" form="{form}" placeholder="{$l('Ex: superman')}">
    <span slot="label">{$l('Nickname')}</span>
  </TextField>
  <TextField name="realname" form="{form}" placeholder="{$l('Ex: Clark Kent')}">
    <span slot="label">{$l('Your name')}</span>
  </TextField>

  {#if connection_id != 'add'}
    <Checkbox name="want_to_be_connected" form="{form}">
      <span slot="label">{$l('Want to be connected')}</span>
    </Checkbox>
  {:else}
    <TextField name="conversation_id" form="{form}" placeholder="{$l('Ex: #convos')}">
      <span slot="label">{$l('Conversation name')}</span>
    </TextField>
  {/if}

  <Checkbox name="tls" form="{form}">
    <span slot="label">{$l('Secure connection (TLS)')}</span>
  </Checkbox>
  <Checkbox name="tls_verify" form="{form}" disabled="{!$form.tls}" hidden="{!$form.tls}">
    <span slot="label">{$l('Verify certificate (TLS)')}</span>
  </Checkbox>
  <Checkbox icon="caret" name="show_advanced_settings" form="{form}">
    <span slot="label">{$l('Advanced settings')}</span>
  </Checkbox>
  {#if $form.show_advanced_settings}
    <div class="form-group" transition:slide="{{duration: 150}}">
      <TextArea name="on_connect_commands" form="{form}" placeholder="{$l('Put each command on a new line.')}">
        <span slot="label">{$l('On-connect commands')}</span>
      </TextArea>
      {#if !user.forced_connection}
        <TextField name="local_address" form="{form}">
          <span slot="label">{$l('Source IP')}</span>
          <p class="help" slot="help">{$l('Leave this blank, unless you know what you are doing.')}</p>
        </TextField>
      {/if}
    </div>
  {/if}

  {#if !user.forced_connection}
    <Checkbox icon="caret" name="show_auth_settings" form="{form}">
      <span slot="label">{$l('Authentication settings')}</span>
    </Checkbox>
    {#if $form.show_auth_settings}
      <div class="form-group" transition:slide="{{duration: 150}}">
        <TextField name="username" form="{form}" placeholder="{$form.nick}">
          <span slot="label">{$l('Username')}</span>
          <p class="help" slot="help">{$l('SASL and IRC server username.')}</p>
        </TextField>
        {#if $form.sasl == 'external'}
          <TextField type="text" name="fingerprint" form="{form}" readonly="{true}">
            <span slot="label">{$l('Fingerprint')}</span>
            <p class="help" slot="help">{$l('The certificate fingerprint is used for SASL external authentication.')}</p>
          </TextField>
        {:else}
          <TextField type="password" name="password" form="{form}">
            <span slot="label">{$l('Password')}</span>
            <p class="help" slot="help">{$l('SASL plain or IRC server password.')}</p>
          </TextField>
        {/if}
        <SelectField name="sasl" options="{saslMechanisms}" form="{form}">
          <span slot="label">{$l('SASL authentication mechanism')}</span>
        </SelectField>
      </div>
    {/if}
  {/if}

  <div class="form-actions">
    {#if connection_id != 'add'}
      <Button icon="save" op="{updateConnectionOp}"><span>{$l('Update')}</span></Button>
    {:else}
      <Button icon="plus-circle" op="{createConnectionOp}"><span>{$l('Add')}</span></Button>
    {/if}
  </div>
  <OperationStatus op="{createConnectionOp}"/>
  <OperationStatus op="{updateConnectionOp}"/>

  {#if connection_id != 'add'}
    <h3>{$l('Delete')}</h3>
    <p>
      {$l('This will permanently remove chat logs and other connection related data.')}
      {@html $lmd('Please confirm by entering "**%1**" before hitting **%2**.', connection_id, $l('Delete'))}
    </p>

    <TextField name="confirm_connection_id" form="{form}">
      <span slot="label">{$l('Confirm connection ID')}</span>
    </TextField>

    <div class="form-actions">
      <Button icon="trash" op="{removeConnectionOp}" on:click="{removeConnection}" disabled="{$form.confirm_connection_id != connection_id}"><span>{$l('Delete')}</span></Button>
    </div>

    <OperationStatus op="{removeConnectionOp}" success="Deleted."/>
  {/if}
</form>
