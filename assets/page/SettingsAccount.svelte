<script>
import ChatHeader from '../components/ChatHeader.svelte';
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import SelectField from '../components/form/SelectField.svelte';
import TextField from '../components/form/TextField.svelte';
import {getContext, onDestroy} from 'svelte';
import {embedMaker} from '../js/EmbedMaker';
import {l} from '../js/i18n';
import {notify} from '../js/Notify';
import {route} from '../store/Route';

const api = getContext('api');
const user = getContext('user');
const updateUserOp = api('updateUser');

const themes = Object.keys(user.themes).map(id => {
  let name = user.themes[id].name;
  const colorSchemes = Object.keys(user.themes[id].variants || {}).filter(cs => cs != 'default');
  if (colorSchemes.length) name += ' (' + colorSchemes.sort().join('/') + ')';
  return [id, name];
});

let formEl;
let colorSchemeOptions = [];
let colorScheme = user.colorScheme;
let expandUrlToMedia = embedMaker.expandUrlToMedia;
let highlightKeywords = user.highlightKeywords.join(', ');
let theme = user.theme;
let wantNotifications = notify().wantNotifications;

route.update({title: l('Account')});

updateUserOp.on('start', req => {
  if (!req.body.password) delete req.body.password;
  req.body.highlight_keywords = req.body.highlight_keywords.split(/[.,\s]+/).map(str => str.trim());
  user.update({colorScheme, theme, highlightKeywords: req.body.highlight_keywords});
});

onDestroy(notify().on('update', notifyWantNotificationsChanged));

$: calculateColorSchemeOptions(theme);

function calculateColorSchemeOptions(id) {
  const options = [['auto', 'Auto']];
  const theme = user.themes[id] || {variants: {}};
  if (theme.variants.dark) options.push(['dark', 'Dark']);
  if (theme.variants.light) options.push(['light', 'Light']);
  colorSchemeOptions = options;
  colorScheme = 'auto';
}

function notifyWantNotificationsChanged(notify, changed) {
  if (!changed.wantNotifications && !changed.desktopAccess) return;
  if (notify.wantNotifications) notify.show(l('You have enabled notifications.'), {force: true});
}

function updateUserFromForm(e) {
  const form = e.target;
  const passwords = [form.password.value, form.password_again.value];

  if (wantNotifications) {
    notify().requestDesktopAccess();
  }

  if (passwords.join('').length && passwords[0] != passwords[1]) {
    return updateUserOp.error('Passwords does not match.');
  }

  embedMaker.update({expandUrlToMedia});
  notify().update({wantNotifications});
  updateUserOp.perform(e.target);
}
</script>

<ChatHeader>
  <h1>{l('Account')}</h1>
</ChatHeader>

<main class="main">
  <form method="post" on:submit|preventDefault="{updateUserFromForm}" bind:this="{formEl}">
    <TextField type="email" name="email" value="{$user.email}" readonly>
      <span slot="label">{l('Email')}</span>
    </TextField>

    <TextField name="highlight_keywords" placeholder="{l('whatever, keywords')}" value="{highlightKeywords}">
      <span slot="label">{l('Notification keywords')}</span>
    </TextField>

    <Checkbox name="notifications" bind:checked="{wantNotifications}">
      <span slot="label">{l('Enable notifications')}</span>
    </Checkbox>

    <Checkbox name="expand_url" bind:checked="{expandUrlToMedia}">
      <span slot="label">{l('Expand URL to media')}</span>
    </Checkbox>

    <SelectField name="theme" options="{themes}" bind:value="{theme}">
      <span slot="label">{l('Theme')}</span>
    </SelectField>

    <SelectField name="color_scheme" options="{colorSchemeOptions}" bind:value="{colorScheme}">
      <span slot="label">{l('Color scheme')}</span>
    </SelectField>

    <TextField type="password" name="password" autocomplete="new-password">
      <span slot="label">{l('Password')}</span>
    </TextField>
    <TextField type="password" name="password_again" autocomplete="new-password">
      <span slot="label">{l('Repeat password')}</span>
    </TextField>

    <p>{l('Leave the password fields empty to keep the current password.')}</p>

    <div class="form-actions">
      <Button icon="save" op="{updateUserOp}"><span>{l('Save settings')}</span></Button>
    </div>

    <OperationStatus op="{updateUserOp}"/>
  </form>
</main>
