<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import TextField from '../components/form/TextField.svelte';
import Time from '../js/Time';
import {copyToClipboard} from '../js/util';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../store/I18N';
import {notify} from '../js/Notify';
import {route} from '../store/Route';

export let title = 'Users';

const api = getContext('api');
const user = getContext('user');

const deleteUserOp = api('deleteUser');
const getUsersOp = api('getUsers');
const inviteLinkOp = api('inviteUser');
const updateUserOp = api('updateUser');

let confirmEmail = '';
let users = [];

$: editUser = findUser($route, users);
$: invite = $inviteLinkOp.res.body || {};
$: title = editUser ? editUser.email : 'Users';

updateUserOp.on('start', req => {
  editUser.roles = req.body.roles.split(/[.,\s]+/).map(str => str.trim());
  req.body.roles = editUser.roles;
});

onMount(async () => {
  await getUsersOp.perform();
  users = getUsersOp.res.body.users || [];
});

function copyInviteLink(e) {
  const copied = copyToClipboard(e.target);
  if (copied) notify.showInApp(copied, {title: $l('Invite link copied')});
}

async function deleteUserFromForm(e) {
  e.preventDefault();
  deleteUserOp.reset();
  updateUserOp.reset();
  if (confirmEmail != editUser.email) return;

  await deleteUserOp.perform(e.target);
  if (!deleteUserOp.is('success')) return;

  await getUsersOp.perform();
  route.go('/settings/users', {replace: true});
}

function findUser(route, users) {
  const uid = route.hash;
  confirmEmail = '';
  return users.filter(user => user.uid == uid)[0];
}

function generateInviteLink(e) {
  inviteLinkOp.perform(e.target);
}

function updateUserFromForm(e) {
  deleteUserOp.reset();
  updateUserOp.perform(e.target);
}
</script>

<ChatHeader>
  <h1>{$l(editUser ? 'Account' : 'Users')}</h1>
  <Link href="/settings/users" class="btn-hallow {editUser ? 'is-active' : ''}" data-tooltip="{$l('See all users')}"><Icon name="list"/><Icon name="times"/></Link>
</ChatHeader>

<main class="main">
  {#if editUser}
    <form id="edit" method="post" on:submit|preventDefault="{updateUserFromForm}">
      <TextField name="email" value="{editUser.email}" readonly>
        <span slot="label">{$l('Email')}</span>
      </TextField>

      <TextField name="roles" value="{editUser.roles.join(', ')}" placeholder="{$l('admin, bot, ...')}">
        <span slot="label">{$l('Roles')}</span>
        <p class="help" slot="help">{$l('Roles must be separated by comma.')}</p>
      </TextField>

      <div class="form-actions">
        <Button icon="save" op="{updateUserOp}"><span>{$l('Save user')}</span></Button>
      </div>

      <OperationStatus op="{updateUserOp}"/>
    </form>

    <h2>Delete account</h2>
    <form id="delete" method="post" on:submit|preventDefault="{deleteUserFromForm}">
      <p>
        {$l('This will permanently remove user settings, chat logs, uploaded files and other user related data.')}
        {@html $lmd('Please confirm by entering **%1** before hitting **%2**.', editUser.email, $l('Delete user'))}
      </p>

      <TextField name="email" bind:value="{confirmEmail}">
        <span slot="label">{$l('Confirm email')}</span>
      </TextField>

      <div class="form-actions">
        <Button icon="trash" op="{deleteUserOp}" disabled="{confirmEmail != editUser.email}"><span>{$l('Delete user')}</span></Button>
      </div>

      <OperationStatus op="{deleteUserOp}"/>
    </form>
  {:else}
    <form id="invite" method="post" on:submit|preventDefault="{generateInviteLink}">
      <h2>{$l('Invite or recover password')}</h2>
      <TextField type="email" name="email" placeholder="{$l('user@example.com')}">
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
        <Button icon="save" op="{inviteLinkOp}"><span>{$l('Generate link')}</span></Button>
      </div>

      <OperationStatus op="{inviteLinkOp}"/>
    </form>

    <h2>{$l('Users')} <small>({users.length})</small></h2>
    <OperationStatus op="{getUsersOp}" progress="{true}"/>
    <table>
      <thead>
        <tr>
          <th>{$l('Email')}</th>
          <th>{$l('Roles')}</th>
          <th>{$l('Registered')}</th>
        </tr>
      </thead>
      <tbody>
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
