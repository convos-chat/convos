<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import ConnectionURL from '../js/ConnectionURL';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import TextField from '../components/form/TextField.svelte';
import {createForm} from '../store/form';
import {getContext, onMount, tick} from 'svelte';
import {l, lmd} from '../store/I18N';
import {route} from '../store/Route';
import {slide} from 'svelte/transition';
import {str2array} from '../js/util';

export let profile_id = 'add';
export const title = profile_id == 'add' ? 'Add connection profile' : 'Edit connection profile';

const api = getContext('api');
const user = getContext('user');
const connectionProfiles = user.connectionProfiles;
const form = createForm();
const removeConnectionProfileOp = api('removeConnectionProfile');
const saveConnectionProfileOp = api('saveConnectionProfile');

$: form.set($connectionProfiles.find(profile_id) || $connectionProfiles.defaultProfile());
$: isAdmin = user.roles.has('admin');

onMount(() => connectionProfiles.load());

async function removeConnectionProfile() {
  await removeConnectionProfileOp.perform({id: profile_id});
  await connectionProfiles.load({force: true});
  await tick();
  route.go('/settings/connections');
}

async function saveConnectionProfile() {
  const profile = form.get();
  ['is_default', 'is_forced', 'skip_queue'].forEach(k => (profile[k] = !!profile[k]));
  profile.service_accounts = str2array(profile.service_accounts);
  profile.url = new ConnectionURL('irc://localhost').fromFields(profile).toString();

  await saveConnectionProfileOp.perform(profile);
  if (saveConnectionProfileOp.is('error')) return;
  if (profile.is_default) user.update({default_connection: profile.url, forced_connection: profile.is_forced});
  await connectionProfiles.load({force: true});
  await tick();
  route.go('/settings/connections');
}
</script>

<ChatHeader>
  <h1>{profile_id == 'add' ? $l('Add connection profile') : $l('Edit connection profile')}</h1>
  <Link href="/settings/connections" class="btn-hallow is-active" data-tooltip="{$l('See all connection profiles')}"><Icon name="list"/><Icon name="times"/></Link>
</ChatHeader>

<main class="main">
  <form method="post" on:submit|preventDefault="{saveConnectionProfile}">
    <TextField name="host" form="{form}" placeholder="{$l('Ex: irc.libera.chat:6697')}" readonly="{!isAdmin}">
      <span slot="label">{$l('Host and port')}</span>
      <p class="help" slot="help">{$l('Will match connections on hostname.')}</p>
    </TextField>
    <Checkbox name="tls" form="{form}" disabled="{!isAdmin}">
      <span slot="label">{$l('Secure connection (TLS)')}</span>
    </Checkbox>
    <Checkbox name="tls_verify" form="{form}" disabled="{!$form.tls || !isAdmin}" hidden="{!$form.tls}">
      <span slot="label">{$l('Verify certificate (TLS)')}</span>
    </Checkbox>
    <TextField name="conversation_id" form="{form}" placeholder="{$l('Ex: #convos')}" readonly="{!isAdmin}">
      <span slot="label">{$l('Conversation name')}</span>
    </TextField>
    <TextField name="service_accounts" form="{form}" placeholder="{$l('chanserv, nickserv, ...')}" readonly="{!isAdmin}">
      <span slot="label">{$l('Service accounts')}</span>
      <p class="help" slot="help">{$l('Messages from these nicks will be shown in the connection conversation.')}</p>
    </TextField>
    <Checkbox name="is_default" form="{form}" disabled="{!isAdmin}">
      <span slot="label">{$l('Default connection')}</span>
    </Checkbox>
    <Checkbox name="is_forced" form="{form}" disabled="{!isAdmin}" hidden="{!$form.is_default}">
      <span slot="label">{$l('Force default connection')}</span>
    </Checkbox>
    {#if isAdmin}
      <p class="help" hidden="{!$form.is_default}">{$l('Tick this box if you want to prevent users from creating custom connections.')}</p>
    {/if}

    <Checkbox icon="caret" name="show_advanced_settings" form="{form}">
      <span slot="label">{$l('Advanced settings')}</span>
    </Checkbox>
    {#if $form.show_advanced_settings}
      <div class="form-group" transition:slide="{{duration: 150}}">
        <TextField name="max_bulk_message_size" form="{form}" type="number" readonly="{!isAdmin}">
          <span slot="label">{$l('Max number of pasted lines')}</span>
          <p class="help" slot="help">{$l('Setting this value too high might get you banned from the server.')}</p>
        </TextField>
        <TextField name="max_message_length" form="{form}" type="number" readonly="{!isAdmin}">
          <span slot="label">{$l('Max message length')}</span>
          <p class="help" slot="help">{$l('Messages longer than this will be split into multiple messages.')}</p>
        </TextField>
        <TextField name="webirc_password" form="{form}" type="password" readonly="{!isAdmin}">
          <span slot="label">{$l('WEBIRC password')}</span>
        </TextField>
        <Checkbox name="skip_queue" form="{form}" disabled="{!isAdmin}">
          <span slot="label">{$l('Skip connection queue')}</span>
        </Checkbox>
        <p class="help">{$l('This might result in flood ban.')}</p>
      </div>
    {/if}

    {#if !isAdmin}
      <p class="error">{$l('Only administrators can edit this section.')}</p>
    {/if}

    <div class="form-actions">
      {#if profile_id != 'add'}
        <Button icon="save" op="{saveConnectionProfileOp}" disabled="{!isAdmin}"><span>{$l('Update')}</span></Button>
        <Button icon="trash" type="button" op="{removeConnectionProfileOp}" disabled="{!isAdmin}" on:click="{removeConnectionProfile}"><span>{$l('Delete')}</span></Button>
      {:else}
        <Button icon="plus-circle" op="{saveConnectionProfileOp}"><span>{$l('Add')}</span></Button>
      {/if}
    </div>
    <OperationStatus op="{removeConnectionProfileOp}" success="Deleted."/>
    <OperationStatus op="{saveConnectionProfileOp}"/>
  </form>
</main>
