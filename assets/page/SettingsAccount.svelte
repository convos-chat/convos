<script>
import ChatHeader from '../components/ChatHeader.svelte';
import Button from '../components/form/Button.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import Icon from '../components/Icon.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import SelectField from '../components/form/SelectField.svelte';
import TextField from '../components/form/TextField.svelte';
import {getContext, onDestroy} from 'svelte';
import {i18n, l} from '../store/I18N.js';
import {notify} from '../js/Notify';
import {route} from '../store/Route';
import {settings} from '../js/util';

const api = getContext('api');
const themeManager = getContext('themeManager');
const user = getContext('user');
const updateUserOp = api('updateUser');

let formEl;
let activeTheme = themeManager.activeTheme;
let colorScheme = themeManager.colorScheme;
let lang = i18n.lang;
let compactDisplay = themeManager.compactDisplay;
let expandUrlToMedia = user.expandUrlToMedia;
let highlightKeywords = user.highlightKeywords.join(', ');
let ignoreStatuses = user.ignoreStatuses;
let wantNotifications = notify.wantNotifications;

$: colorSchemeReadonly = $themeManager.hasColorScheme(activeTheme) ? false : true;
$: i18n.load(lang);

route.update({title: 'Account'});

updateUserOp.on('start', req => {
  if (!req.body.password) delete req.body.password;
  req.body.highlight_keywords = req.body.highlight_keywords.split(/[.,\s]+/).map(str => str.trim());
  user.update({highlightKeywords: req.body.highlight_keywords});
});


onDestroy(notify.on('update', notifyWantNotificationsChanged));

function notifyWantNotificationsChanged(notify, changed) {
  if (!changed.wantNotifications && !changed.desktopAccess) return;
  if (notify.wantNotifications) notify.show($l('You have enabled notifications.'));
}

function updateFromForm(e) {
  const form = e.target;
  const passwords = [form.password.value, form.password_again.value];

  if (passwords.join('').length && passwords[0] != passwords[1]) return updateUserOp.error('Passwords does not match.');
  if (colorSchemeReadonly) colorScheme = 'auto';
  if (wantNotifications) notify.requestDesktopAccess();

  notify.update({wantNotifications});
  themeManager.update({activeTheme, colorScheme, compactDisplay});
  user.update({expandUrlToMedia, ignoreStatuses});
  updateUserOp.perform(e.target);
}
</script>

<ChatHeader>
  <h1>{$l('Account')}</h1>
</ChatHeader>

<main class="main">
  <form method="post" on:submit|preventDefault="{updateFromForm}" bind:this="{formEl}">
    <TextField type="email" name="email" value="{$user.email}" readonly>
      <span slot="label">{$l('Email')}</span>
    </TextField>

    <TextField name="highlight_keywords" placeholder="{$l('whatever, keywords')}" value="{highlightKeywords}">
      <span slot="label">{$l('Notification keywords')}</span>
    </TextField>

    <Checkbox name="notifications" bind:checked="{wantNotifications}">
      <span slot="label">{$l('Enable notifications')}</span>
    </Checkbox>
    
    <Checkbox name="statuses" bind:checked="{ignoreStatuses}">
      <span slot="label">{$l('Ignore join/part messages')}</span>
    </Checkbox>

    <Checkbox name="expand_url" bind:checked="{expandUrlToMedia}">
      <span slot="label">{$l('Expand URL to media')}</span>
    </Checkbox>

    <SelectField name="theme" options="{themeManager.themeOptions}" bind:value="{activeTheme}">
      <span slot="label">{$l('Theme')}</span>
    </SelectField>

    <SelectField name="color_scheme" readonly="{colorSchemeReadonly}" options="{themeManager.colorSchemeOptions}" bind:value="{colorScheme}">
      <span slot="label">{$l('Color scheme')}</span>
    </SelectField>

    <Checkbox name="compact" bind:checked="{compactDisplay}">
      <span slot="label">{$l('Enable compact message display')}</span>
    </Checkbox>

    <SelectField name="lang" options="{$i18n.languageOptions}" bind:value="{lang}">
      <span slot="label">{$l('Language')} <Icon name="globe"/></span>
    </SelectField>

    <TextField type="password" name="password" autocomplete="new-password">
      <span slot="label">{$l('Password')}</span>
    </TextField>

    <TextField type="password" name="password_again" autocomplete="new-password">
      <span slot="label">{$l('Repeat password')}</span>
    </TextField>

    <p>{$l('Leave the password fields empty to keep the current password.')}</p>

    <div class="form-actions">
      <Button icon="save" op="{updateUserOp}"><span>{$l('Save settings')}</span></Button>
    </div>

    <OperationStatus op="{updateUserOp}"/>
  </form>
</main>
