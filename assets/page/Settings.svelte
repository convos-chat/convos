<script>
import {getContext, tick} from 'svelte';
import {l} from '../js/i18n';
import Checkbox from '../components/form/Checkbox.svelte';
import FormActions from '../components/form/FormActions.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import PasswordField from '../components/form/PasswordField.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import TextField from '../components/form/TextField.svelte';

const user = getContext('user');
const enableNotifications = user.enableNotifications;
const expandUrlToMedia = user.expandUrlToMedia;
const updateUserOp = user.api.operation('updateUser');

let formEl;

async function updateUserFromForm(e) {
  const form = e.target;
  const passwords = [form.password.value, form.password_again.value];

  if (!form.notifications.checked) {
    $enableNotifications = 'default';
  }
  else if ($enableNotifications != 'granted') {
    $enableNotifications = 'pending';
    Notification.requestPermission(status => { $enableNotifications = status });
  }

  if (passwords.join('').length && passwords[0] != passwords[1]) {
    return updateUserOp.error('Passwords does not match.');
  }

  $expandUrlToMedia = form.expand_url.checked;
  updateUserOp.execute(e.target);
}

// TODO: Figure out a better way to uncheck
$: if (formEl && $enableNotifications == 'granted' && !formEl.notifications.checked) formEl.notifications.click();
$: if (formEl && $enableNotifications == 'denied' && formEl.notifications.checked) formEl.notifications.click();
$: if (formEl && $user.res.body.highlightKeywords) formEl.highlight_keywords.value = $user.res.body.highlightKeywords;
</script>

<SidebarChat/>

<main class="main-app-pane align-content-middle">
  <h1>{l('Settings')}</h1>
  <form method="post" on:submit|preventDefault="{updateUserFromForm}" bind:this="{formEl}">
    <TextField name="email" value="{$user.email}" readonly>
      <span slot="label">{l('Email')}</span>
    </TextField>
    <TextField name="highlight_keywords">
      <span slot="label">{l('Notification keywords')}</span>
    </TextField>

    <Checkbox name="notifications" disabled="{$enableNotifications == 'denied'}">
      <span slot="label">{l('Enable notifications')}</span>
    </Checkbox>

    <Checkbox name="expand_url">
      <span slot="label">{l('Expand URL to media')}</span>
    </Checkbox>

    <h2>{l('New password')}</h2>
    <PasswordField name="password">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <PasswordField name="password_again">
      <span slot="label">{l('Repeat password')}</span>
    </PasswordField>

    <FormActions>
      <button class="btn">{l('Save settings')}</button>
    </FormActions>
    <OperationStatus op={updateUserOp}/>
  </form>
</main>
