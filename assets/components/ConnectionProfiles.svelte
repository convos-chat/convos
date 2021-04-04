<script>
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import Icon from '../components/Icon.svelte';
import TextField from '../components/form/TextField.svelte';
import ConnectionURL from '../js/ConnectionURL';
import OperationStatus from '../components/OperationStatus.svelte';
import {formAction, makeFormStore} from '../store/form';
import {generateWriteable} from '../store/writable';
import {is} from '../js/util';
import {l, lmd} from '../store/I18N';
import {getContext, onMount} from 'svelte';
import {route} from '../store/Route';
import {slide} from 'svelte/transition';

export let editProfile = null;

const api = getContext('api');
const user = getContext('user');

const connectionProfiles = generateWriteable('connectionProfiles', []);
const form = makeFormStore({});
const listConnectionProfiles = api('listConnectionProfiles');
const removeConnectionProfileOp = api('removeConnectionProfileOp');
const saveConnectionProfileOp = api('saveConnectionProfile');

let showAdvancedSettings = false;

$: isAdmin = user.roles.has('admin');
$: findProfile($route, $connectionProfiles);
$: if (showAdvancedSettings) form.renderOnNextTick();

onMount(async () => {
  form.submit = saveConnectionProfile;
  if ($connectionProfiles.length) return;
  await listConnectionProfiles.perform();
  $connectionProfiles = listConnectionProfiles.res.body.profiles.map(normalizeProfile);
});

function findProfile(route, $connectionProfiles) {
  const profileId = route.hash.replace(/^profile-/, '');
  editProfile = profileId == 'add'
    ? {max_bulk_message_size: 3, max_message_length: 512, url: new ConnectionURL('irc://0.0.0.0')}
    : $connectionProfiles.filter(p => p.id == profileId)[0] || null;

  if (!editProfile) return;
  editProfile.url.toFields(editProfile);
  if (editProfile.host == '0.0.0.0') editProfile.host = '';
  form.renderOnNextTick(editProfile);
}

function normalizeProfile(profile) {
  profile.url = new ConnectionURL(profile.url);
  profile.service_accounts = profile.service_accounts.join(', ');
  profile.url.toFields(profile);
  return profile;
}

async function saveConnectionProfile() {
  const params = {};
  ['is_default', 'is_forced'].forEach(k => (params[k] = !!$form[k]));
  ['max_bulk_message_size', 'max_message_length', 'webirc_password'].forEach(k => (params[k] = $form[k]));
  params.service_accounts = $form.service_accounts.split(/\s*,\s*/).map(nick => nick.trim()).filter(nick => nick.length);
  params.url = new ConnectionURL('irc://localhost').fromFields($form).toString();

  await saveConnectionProfileOp.perform(params);
  if (saveConnectionProfileOp.is('error')) return;

  const profile = normalizeProfile(saveConnectionProfileOp.res.body);
  $connectionProfiles = $connectionProfiles.filter(p => p.id != profile.id)
    .concat(profile)
    .sort((a, b) => a.id.localeCompare(b.id))
    .map(p => {
      if (profile.is_default && p.id != profile.id) p.is_default = p.is_forced = false;
      return p;
    });

  if (profile.is_default) {
    user.update({default_connection: profile.url.toString(), forced_connection: profile.is_forced});
  }

  showAdvancedSettings = false;
  route.go('/settings/connections');
}
</script>

{#if editProfile}
  <form method="post" use:formAction="{form}">
    <TextField name="host" placeholder="{$l('Ex: chat.freenode.net:6697')}" readonly="{!isAdmin}">
      <span slot="label">{$l('Host and port')}</span>
      <p class="help" slot="help">{$l('Will match connections on hostname.')}</p>
    </TextField>
    <Checkbox name="tls" disabled="{!isAdmin}">
      <span slot="label">{$l('Secure connection (TLS)')}</span>
    </Checkbox>
    <Checkbox name="tls_verify" disabled="{!$form.tls || !isAdmin}" hidden="{!$form.tls}">
      <span slot="label">{$l('Verify certificate (TLS)')}</span>
    </Checkbox>
    <TextField name="conversation_id" placeholder="{$l('Ex: #convos')}">
      <span slot="label">{$l('Conversation name')}</span>
    </TextField>
    <TextField name="service_accounts" placeholder="{$l('chanserv, nickserv, ...')}" readonly="{!isAdmin}">
      <span slot="label">{$l('Service accounts')}</span>
      <p class="help" slot="help">{$l('Messages from these nicks will be shown in the connection conversation.')}</p>
    </TextField>

    <Checkbox name="is_default">
      <span slot="label">{$l('Default connection')}</span>
    </Checkbox>
    <Checkbox name="is_forced" hidden="{!$form.is_default}">
      <span slot="label">{$l('Force default connection')}</span>
    </Checkbox>
    <p class="help" hidden="{!$form.is_default}">{$l('Tick this box if you want to prevent users from creating custom connections.')}</p>

    <Checkbox bind:checked="{showAdvancedSettings}">
      <span slot="label">{$l('Show advanced settings')}</span>
    </Checkbox>
    {#if showAdvancedSettings}
      <div class="form-group" transition:slide="{{duration: 150}}">
        <TextField name="max_bulk_message_size" type="number" readonly="{!isAdmin}">
          <span slot="label">{$l('Max number of pasted lines')}</span>
          <p class="help" slot="help">{$l('Setting this value too high might get you banned from the server.')}</p>
        </TextField>
        <TextField name="max_message_length" type="number" readonly="{!isAdmin}">
          <span slot="label">{$l('Max message length')}</span>
          <p class="help" slot="help">{$l('Messages longer than this will be split into multiple messages.')}</p>
        </TextField>
        <TextField name="webirc_password" type="password" readonly="{!isAdmin}">
          <span slot="label">{$l('WEBIRC password')}</span>
        </TextField>
      </div>
    {/if}

    {#if isAdmin}
      <div class="form-actions">
        {#if editProfile.id}
          <Button icon="save" op="{saveConnectionProfileOp}"><span>{$l('Update')}</span></Button>
        {:else}
          <Button icon="save" op="{saveConnectionProfileOp}"><span>{$l('Add')}</span></Button>
        {/if}
      </div>
      <OperationStatus op="{saveConnectionProfileOp}"/>
    {/if}
  </form>
{:else}
  <h2>{$l('Connection profiles')}</h2>
  <p>{$l('Connection profiles are used to set up global values for every connection that connect to the same host.')}</p>
  <OperationStatus op="{listConnectionProfiles}" progress="{true}"/>
  <table>
    <thead>
      <tr>
        <th>{$l('Server')}</th>
        <th>{$l('Secure')}</th>
        <th>{$l('Default')}</th>
        <th>{$l('Forced')}</th>
      </tr>
    </thead>
    <tbody>
      {#each $connectionProfiles as profile}
        <tr>
          <td><a href="#profile-{profile.id}">{profile.url.host}</a></td>
          <td>{is.true(profile.tls_verify) ? $l('Strict') : is.true(profile.tls) ? $l('Yes') : $l('No')}</td>
          <td>{profile.is_default ? $l('Yes') : $l('No')}</td>
          <td>{profile.is_forced ? $l('Yes') : $l('No')}</td>
        </tr>
      {/each}
    </tbody>
  </table>
  {#if isAdmin}
    <div class="form-actions">
      <a href="#profile-add" class="btn"><Icon name="plus-circle"/> <span>{$l('Add')}</span></a>
    </div>
  {/if}
{/if}
