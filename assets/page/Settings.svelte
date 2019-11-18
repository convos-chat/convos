<script>
import ChatHeader from '../components/ChatHeader.svelte';
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import TextField from '../components/form/TextField.svelte';
import {getContext, onMount} from 'svelte';
import {l} from '../js/i18n';

const user = getContext('user');
const getSettingsOp = user.api.operation('getSettings');
const updateSettingsOp = user.api.operation('updateSettings');

let settings = {};

updateSettingsOp.on('start', req => {
  req.body.contact = 'mailto:' + req.body.contact;
  req.body.open_to_public = req.body.open_to_public ? true : false;
});

function updateSettingsFromForm(e) {
  updateSettingsOp.perform(e.target);
}

onMount(async () => {
  await getSettingsOp.perform();
  const body = getSettingsOp.res.body;
  body.contact = body.contact.replace(/mailto:/, '');
  settings = body;
});
</script>

<ChatHeader>
  <h1>{l('Settings')}</h1>
</ChatHeader>

<main class="main">
  <form method="post" on:submit|preventDefault="{updateSettingsFromForm}">
    <TextField name="organization_name" placeholder="{l('Nordaaker')}" bind:value="{settings.organization_name}">
      <span slot="label">{l('Organization name')}</span>
    </TextField>

    <TextField name="organization_url" placeholder="{l('https://convos.by')}" bind:value="{settings.organization_url}">
      <span slot="label">{l('Organization URL')}</span>
    </TextField>

    <TextField name="contact" placeholder="{l('Ex: jhthorsen@cpan.org')}" bind:value="{settings.contact}">
      <span slot="label">{l('Admin email')}</span>
    </TextField>

    <TextField name="default_connection" placeholder="{l('irc://chat.freenode.net:6697/%%23convos')}" bind:value="{settings.default_connection}">
      <span slot="label">{l('Default connection URL')}</span>
    </TextField>

    <Checkbox name="open_to_public" checked="{settings.open_to_public}">
      <span slot="label">{l('Open to public')}</span>
    </Checkbox>

    <div class="form-actions">
      <Button icon="save" op="{updateSettingsOp}">{l('Save settings')}</Button>
    </div>

    <OperationStatus op="{updateSettingsOp}"/>
  </form>
</main>
