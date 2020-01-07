<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import TextField from '../components/form/TextField.svelte';
import {copyToClipboard} from '../js/util';
import {docTitle} from '../store/router';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';

const settings = getContext('settings');
const user = getContext('user');
const getSettingsOp = user.api.operation('getSettings');
const inviteLinkOp = user.api.operation('inviteUser');
const updateSettingsOp = user.api.operation('updateSettings');

let convosSettings = {};

$docTitle = l('%1 - Convos', l('Convos settings'));

$: invite = $inviteLinkOp.res.body || {};

updateSettingsOp.on('start', req => {
  if (req.body.contact) req.body.contact = 'mailto:' + req.body.contact;
  req.body.open_to_public = req.body.open_to_public ? true : false;
});

function generateInviteLink(e) {
  inviteLinkOp.perform(e.target);
}

function copyInviteLink(e) {
  const copied = copyToClipboard(e.target);
  if (copied) user.events.notifyUser('Invite link copied', copied, {force: true});
}

function updateSettingsFromForm(e) {
  updateSettingsOp.perform(e.target);
}

onMount(async () => {
  await getSettingsOp.perform();
  const body = getSettingsOp.res.body;
  body.contact = body.contact.replace(/mailto:/, '');
  convosSettings = body;
});
</script>

<ChatHeader>
  <h1>{l('Settings')}</h1>
</ChatHeader>

<main class="main">
  <form method="post" on:submit|preventDefault="{generateInviteLink}">
    <h2>{l('Recover or invite')}</h2>
    <p>{l('Using this form, you can generate an invite link for new users, or a recover password link for existing users.')}</p>
    <TextField name="email" placeholder="{l('user@example.com')}">
      <span slot="label">{l('User email')}</span>
    </TextField>

    {#if invite.url}
      <h3>{l('A link was generated')}</h3>
      <p>
        {@html lmd(invite.existing ? 'Copy and send the link to your *existing* user.' : 'Copy and send the link to your *new* user.')}
        {@html lmd('The link is valid until **%1**.', new Date(invite.expires).toLocaleString())}
      </p>
      <a href="{invite.url}" on:click|preventDefault="{copyInviteLink}">{invite.url}</a>
      <p><small>{l('Tip: Clicking on the link will copy it to your clipboard.')}</small></p>
    {/if}

    <div class="form-actions">
      <Button icon="save" op="{inviteLinkOp}">{l('Generate link')}</Button>
    </div>

    <OperationStatus op="{inviteLinkOp}"/>
  </form>

  <form method="post" on:submit|preventDefault="{updateSettingsFromForm}">
    <h2>{l('Convos settings')}</h2>
    <p>{@html lmd('These settings control what users experience when they visit [%1](%1).', settings.base_url)}</p>

    <TextField name="organization_name" placeholder="{l('Nordaaker')}" bind:value="{convosSettings.organization_name}">
      <span slot="label">{l('Organization name')}</span>
      <p slot="help">{l('Can be changed if you want to add a touch of your organization.')}</p>
    </TextField>

    <TextField name="organization_url" placeholder="{l('https://convos.by')}" bind:value="{convosSettings.organization_url}">
      <span slot="label">{l('Organization URL')}</span>
      <p slot="help">{l('Used together with "Organization name" to add a link to your organization on the login screen.')}</p>
    </TextField>

    <TextField name="contact" placeholder="{l('Ex: jhthorsen@cpan.org')}" bind:value="{convosSettings.contact}">
      <span slot="label">{l('Admin email')}</span>
      <p slot="help">{l('This email can be used by users to get in touch with the Convos admin.')}</p>
    </TextField>

    <TextField name="default_connection" placeholder="{l('irc://chat.freenode.net:6697/%%23convos')}" bind:value="{convosSettings.default_connection}">
      <span slot="label">{l('Default connection URL')}</span>
      <p slot="help">
        {l('This is the default connection new users will connect to.')}
        {l('The path part is the default channel to join. "%%23convos" means "#convos".')}
      </p>
    </TextField>

    <Checkbox name="open_to_public" checked="{convosSettings.open_to_public}">
      <span slot="label">{l('Registration is open to public')}</span>
      <p slot="help">{l('Tick this box if you want users to be able to register without an invite URL.')}</p>
    </Checkbox>

    <div class="form-actions">
      <Button icon="save" op="{updateSettingsOp}">{l('Save settings')}</Button>
    </div>

    <OperationStatus op="{updateSettingsOp}"/>
  </form>
</main>
