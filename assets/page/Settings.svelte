<script>
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import ChatHeader from '../components/ChatHeader.svelte';
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import TextField from '../components/form/TextField.svelte';

const user = getContext('user');
const events = user.events;
const updateUserOp = user.api.operation('updateUser');

let formEl;
let notificationsDisabled = Notification.permission == 'denied';
let wantNotifications = events.wantNotifications;

function updateUserFromForm(e) {
  const form = e.target;
  const passwords = [form.password.value, form.password_again.value];

  if (wantNotifications && Notification.permission != 'granted') {
    Notification.requestPermission(status => {
      if (status != 'denied') return;
      wantNotifications = false;
      notificationsDisabled = true;
    });
  }

  if (passwords.join('').length && passwords[0] != passwords[1]) {
    return updateUserOp.error('Passwords does not match.');
  }

  events.update({wantNotifications});
  user.update({expandUrlToMedia: form.expand_url.checked});
  updateUserOp.perform(e.target);
}
</script>

<SidebarChat/>

<main class="main">
  <ChatHeader>
    <h1>{l('Settings')}</h1>
  </ChatHeader>

  <form method="post" on:submit|preventDefault="{updateUserFromForm}" bind:this="{formEl}">
    <TextField name="email" value="{$user.email}" readonly>
      <span slot="label">{l('Email')}</span>
    </TextField>
    <TextField name="highlight_keywords" placeholder="{l('whatever, keywords')}">
      <span slot="label">{l('Notification keywords')}</span>
    </TextField>

    <Checkbox name="notifications" bind:checked="{wantNotifications}">
      <span slot="label">{l('Enable notifications')}</span>
    </Checkbox>

    {#if notificationsDisabled}
      <p class="error">{l('You cannot receive notifications, because it is denied in your browser settings.')}</p>
    {/if}

    <Checkbox name="expand_url">
      <span slot="label">{l('Expand URL to media')}</span>
    </Checkbox>

    <PasswordField name="password" placeholder="{l('It is optional to change passwords')}">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <PasswordField name="password_again">
      <span slot="label">{l('Repeat password')}</span>
    </PasswordField>

    <div class="form-actions">
      <Button icon="save" op="{updateUserOp}">{l('Save settings')}</Button>
    </div>

    <OperationStatus op="{updateUserOp}"/>
  </form>
</main>
