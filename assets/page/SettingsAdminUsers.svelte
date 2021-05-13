<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import OperationStatusRow from '../components/OperationStatusRow.svelte';
import SimpleField from '../components/form/SimpleField.svelte';
import TextField from '../components/form/TextField.svelte';
import Time from '../js/Time';
import {copyToClipboard, str2array} from '../js/util';
import {createForm} from '../store/form';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../store/I18N';
import {notify} from '../js/Notify';
import {route} from '../store/Route';

export let title = 'Users';

const api = getContext('api');
const form = createForm();
const user = getContext('user');

const deleteUserOp = api('deleteUser');
const getUsersOp = api('getUsers');
const inviteLinkOp = api('inviteUser');
const updateUserOp = api('updateUser');

let users = [];

$: findUser($route, users);
$: invite = $inviteLinkOp.res.body || {};
$: title = $form.uid ? $form.email : 'Users';

onMount(loadUsers);

function copyInviteLink(e) {
  const copied = copyToClipboard(e.target);
  if (copied) notify.showInApp(copied, {title: $l('Invite link copied')});
}

async function deleteUser() {
  deleteUserOp.reset();
  updateUserOp.reset();
  if (form.get('confirm_email') != form.get('email')) return;

  await deleteUserOp.perform(form.get());
  if (!deleteUserOp.is('success')) return;

  loadUsers();
  route.go('/settings/users', {replace: true});
}

function findUser($route, users) {
  const uid = $route.hash;
  const user = uid && users.filter(user => user.uid == uid)[0];
  if (!user) return form.set({confirm_email: '', uid: ''});
  form.set({confirm_email: ''}).set(user);
}

function generateInviteLink() {
  inviteLinkOp.perform(form.get(['email']));
}

async function loadUsers() {
  await getUsersOp.perform();
  users = getUsersOp.res.body.users || [];
  getUsersOp.reset();
}

function updateUser() {
  deleteUserOp.reset();
  updateUserOp.perform({email: form.get('email'), roles: str2array(form.get('roles'))});
}
</script>

<ChatHeader>
  <h1>{$l($form.uid ? 'Account' : 'Users')}</h1>
  <Link href="/settings/users" class="btn-hallow {$form.uid ? 'is-active' : ''}" data-tooltip="{$l('See all users')}"><Icon name="list"/><Icon name="times"/></Link>
</ChatHeader>

<main class="main">
  {#if $form.uid}
    <form id="edit" method="post" on:submit|preventDefault="{updateUser}">
      <SimpleField name="uid" form="{form}"/>
      <TextField name="email" form="{form}" readonly>
        <span slot="label">{$l('Email')}</span>
      </TextField>
      <TextField name="roles" form="{form}" placeholder="{$l('admin, bot, ...')}">
        <span slot="label">{$l('Roles')}</span>
        <p class="help" slot="help">{$l('Roles must be separated by comma.')}</p>
      </TextField>
      <div class="form-actions">
        <Button icon="save" op="{updateUserOp}"><span>{$l('Save user')}</span></Button>
      </div>
      <OperationStatus op="{updateUserOp}"/>
    </form>

    <h2>Delete account</h2>
    <form id="delete" method="post" on:submit|preventDefault="{deleteUser}">
      <p>
        {$l('This will permanently remove user settings, chat logs, uploaded files and other user related data.')}
        {@html $lmd('Please confirm by entering **%1** before hitting **%2**.', $form.email, $l('Delete user'))}
      </p>

      <TextField name="confirm_email" form="{form}">
        <span slot="label">{$l('Confirm email')}</span>
      </TextField>

      <div class="form-actions">
        <Button icon="trash" op="{deleteUserOp}" disabled="{$form.confirm_email != $form.email}"><span>{$l('Delete user')}</span></Button>
      </div>

      <OperationStatus op="{deleteUserOp}" success="Deleted."/>
    </form>
  {:else}
    <form id="invite" method="post" on:submit|preventDefault="{generateInviteLink}">
      <h2>{$l('Invite or recover password')}</h2>
      <TextField type="email" name="email" form="{form}" placeholder="{$l('user@example.com')}">
        <span slot="label">{$l('User email')}</span>
        <p class="help" slot="help">{$l('Using this form, you can generate a forgotten password or invite link for a user.')}</p>
      </TextField>

      {#if invite.url}
        <h3>{$l('A link was generated')}</h3>
        <p>
          {@html $lmd(invite.existing ? 'Copy and send the link to your *existing* user.' : 'Copy and send the link to your *new* user.')}
          {@html $lmd('The link is valid until **%1**.', new Date(invite.expires).toLocaleString())}
        </p>
        <a href="{invite.url}" on:click|preventDefault="{copyInviteLink}">{invite.url}</a>
        <p><small>{$l('Tip: Clicking on the link will copy it to your clipboard.')}</small></p>
      {/if}

      <div class="form-actions">
        <Button icon="save" op="{inviteLinkOp}" disabled="{!$form.email}"><span>{$l('Generate link')}</span></Button>
      </div>

      <OperationStatus op="{inviteLinkOp}" success="Link generated."/>
    </form>

    <h2>{$l('Users')} <small>({users.length})</small></h2>
    <table>
      <thead>
        <tr>
          <th>{$l('Email')}</th>
          <th>{$l('Roles')}</th>
          <th>{$l('Registered')}</th>
        </tr>
      </thead>
      <tbody>
        <OperationStatusRow colspan="3" op="{$getUsersOp}"/>
        {#each users as user}
          <tr>
            <td><a href="#{user.uid}">{user.email}</a></td>
            <td>{user.roles.join(', ')}</td>
            <td>{new Time(user.registered).getHumanDate({year: true})}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</main>
