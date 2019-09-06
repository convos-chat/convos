<script>
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import ChatHeader from '../components/ChatHeader.svelte';
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import FormActions from '../components/form/FormActions.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import TextField from '../components/form/TextField.svelte';

const user = getContext('user');
const updateUserOp = user.api.operation('updateUser');

let formEl;

async function updateUserFromForm(e) {
  const form = e.target;
  const passwords = [form.password.value, form.password_again.value];

  if (!form.notifications.checked) {
    user.update({enableNotifications: 'default'});
  }
  else if (user.enableNotifications != 'granted') {
    user.update({enableNotifications: 'pending'});
    Notification.requestPermission(status => { user.update({enableNotifications: status}) });
  }

  if (passwords.join('').length && passwords[0] != passwords[1]) {
    return updateUserOp.error('Passwords does not match.');
  }

  user.update({expandUrlToMedia: form.expand_url.checked});
  updateUserOp.perform(e.target);
}

// TODO: Figure out a better way to uncheck
$: if (formEl && $user.enableNotifications == 'granted' && !formEl.notifications.checked) formEl.notifications.click();
$: if (formEl && $user.enableNotifications == 'denied' && formEl.notifications.checked) formEl.notifications.click();
$: if (formEl && $user.res.body.highlightKeywords) formEl.highlight_keywords.value = $user.res.body.highlightKeywords;
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

    <Checkbox name="notifications" disabled="{$user.enableNotifications == 'denied'}">
      <span slot="label">{l('Enable notifications')}</span>
    </Checkbox>

    <Checkbox name="expand_url">
      <span slot="label">{l('Expand URL to media')}</span>
    </Checkbox>

    <PasswordField name="password" placeholder="{l('It is optional to change passwords')}">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <PasswordField name="password_again">
      <span slot="label">{l('Repeat password')}</span>
    </PasswordField>

    <FormActions>
      <Button icon="save" op="{updateUserOp}">{l('Save settings')}</Button>
    </FormActions>

    <OperationStatus op={updateUserOp}/>
  </form>
</main>
