<script>
import {getContext, onMount} from 'svelte';
import {l} from '../js/i18n';
import Link from './Link.svelte';

let connections = [];
let email = '';
let unread = 0;

const api = getContext('api');
const byName = (a, b) => a.name.localeCompare(b.name);

function loadConversations() {
  api.execute('getUser', {
    connections: true,
    dialogs: true,
    notifications: false,
  }).then(res => {
    email = res.email;
    unread = res.unread;

    const map = {};
    res.connections.forEach(conn => {
      map[conn.connection_id] = {...conn, channels: [], private: []};
    });

    res.dialogs.forEach(dialog => {
      const conn = map[dialog.connection_id] || {};
      dialog.path = encodeURIComponent(dialog.dialog_id);
      conn[dialog.is_private ? 'private' : 'channels'].push(dialog);
    });

    connections = Object.keys(map).sort().map(id => {
      map[id].channels.sort(byName);
      map[id].private.sort(byName);
      return map[id];
    });
  });
}

onMount(() => {
  loadConversations();
});
</script>

<div class="sidebar-wrapper">
  <div class="sidebar is-chatting">
    <h1 class="sidebar__logo">
      <Link href="/chat"><span>{l('Convos')}</span></Link>
    </h1>

    <nav class="sidebar__nav">
      {#if connections.length}
        <h2>{l('Group dialogs')}</h2>
        <ul class="sidebar__nav__servers for-group-dialogs">
          {#each connections as connection}
            <li>
              <Link href="/chat/{connection.connection_id}" className="is-heading">{l(connection.name)}</Link>
              <ul class="sidebar__nav__conversations is-channels">
                {#each connection.channels as dialog}
                  <li>
                    <Link href="/chat/{connection.connection_id}/{dialog.path}">{dialog.name.replace(/^\W/, '')}</Link>
                  </li>
                {/each}
              </ul>
            </li>
          {/each}
        </ul>

        <h2>{l('Private dialogs')}</h2>
        <ul class="sidebar__nav__servers for-private-dialogs">
          {#each connections as connection}
            {#if connection.private.length}
              <li>
                <Link href="/chat/{connection.connection_id}" className="is-heading">{l(connection.name)}</Link>
                <ul class="sidebar__nav__conversations is-private">
                  {#each connection.private as dialog}
                    <li>
                      <Link href="/chat/{connection.connection_id}/{dialog.path}">{dialog.name}</Link>
                    </li>
                  {/each}
                </ul>
              </li>
            {/if}
          {/each}
        </ul>
      {/if}

      <h2>{email || l('Account')}</h2>
      <Link href="/join" className="sidebar__nav__join">{l('Join dialog...')}</Link>
      <Link href="/connections" className="sidebar__nav__connections">{l('Add connection...')}</Link>
      <Link href="/settings" className="sidebar__nav__settings">{l('Settings')}</Link>
      <Link href="/help" className="sidebar__nav__help">{l('Help')}</Link>
      <Link href="/logout" className="sidebar__nav__logout">{l('Log out')}</Link>
    </nav>
  </div>
</div>