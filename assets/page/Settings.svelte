<script>
import ChatHeader from '../components/ChatHeader.svelte';
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SelectField from '../components/form/SelectField.svelte';
import TextField from '../components/form/TextField.svelte';
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import {themes} from '../settings';

const user = getContext('user');
const updateUserOp = user.api.operation('updateUser');

let formEl;
let expandUrlToMedia = user.expandUrlToMedia;
let notificationsDisabled = user.events.browserNotifyPermission == 'denied';
let theme = user.theme;
let wantNotifications = user.wantNotifications;
let highlight_keywords = user.highlight_keywords.join(', ');

updateUserOp.on('start', req => {
  if (!req.body.password) delete req.body.password;
  req.body.highlight_keywords = req.body.highlight_keywords.split(/[.,\s]+/).map(str => str.trim());
});

function updateUserFromForm(e) {
  const form = e.target;
  const passwords = [form.password.value, form.password_again.value];

  if (wantNotifications) {
    user.events.requestPermissionToNotify(status => {
      if (status != 'denied') return;
      wantNotifications = false;
      notificationsDisabled = true;
    });
  }

  if (passwords.join('').length && passwords[0] != passwords[1]) {
    return updateUserOp.error('Passwords does not match.');
  }

  user.update({expandUrlToMedia, theme});
  updateUserOp.perform(e.target);
}
</script>

<ChatHeader>
  <h1>{l('Settings')}</h1>
</ChatHeader>

<main class="main">
  <form method="post" on:submit|preventDefault="{updateUserFromForm}" bind:this="{formEl}">
    <TextField name="email" value="{$user.email}" readonly>
      <span slot="label">{l('Email')}</span>
    </TextField>

    <TextField name="highlight_keywords" placeholder="{l('whatever, keywords')}" value="{highlight_keywords}">
      <span slot="label">{l('Notification keywords')}</span>
    </TextField>

    {#if !notificationsDisabled}
      <Checkbox name="notifications" bind:checked="{wantNotifications}">
        <span slot="label">{l('Enable notifications')}</span>
      </Checkbox>
    {/if}

    <Checkbox name="expand_url" bind:checked="{expandUrlToMedia}">
      <span slot="label">{l('Expand URL to media')}</span>
    </Checkbox>

    <SelectField name="theme" options="{themes}" bind:value="{theme}">
      <span slot="label">{l('Theme')}</span>
    </SelectField>

    <PasswordField name="password">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <PasswordField name="password_again">
      <span slot="label">{l('Repeat password')}</span>
    </PasswordField>

    <p>{l('Leave the password fields empty to keep the current password.')}</p>

    <div class="form-actions">
      <Button icon="save" op="{updateUserOp}">{l('Save settings')}</Button>
    </div>

    <OperationStatus op="{updateUserOp}"/>

    {#if notificationsDisabled}
      <p class="error">{l('You cannot receive notifications, because it is denied by your browser.')}</p>
    {/if}
  </form>
</main>
