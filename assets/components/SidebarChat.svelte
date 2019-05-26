<script>
import {connectionsWithChannels, email} from '../store/user';
import {l} from '../js/i18n';
import Link from './Link.svelte';
import Unread from './Unread.svelte';
</script>

<div class="sidebar-wrapper">
  <div class="sidebar is-chatting">
    <h1 class="sidebar__logo">
      <Link href="/chat"><span>{l('Convos')}</span></Link>
    </h1>

    <nav class="sidebar__nav">
      {#if $connectionsWithChannels.length}
        <h2>{l('Group dialogs')}</h2>
        <ul class="sidebar__nav__servers for-group-dialogs">
          {#each $connectionsWithChannels as connection}
            <li>
              <Link href="/chat/{connection.connection_id}" className="is-heading">{l(connection.name)}</Link>
              <ul class="sidebar__nav__conversations is-channels">
                {#each connection.channels as dialog}
                  <li>
                    <Link href="/chat/{connection.connection_id}/{dialog.path}">
                      <span>{dialog.name.replace(/^\W/, '')}</span>
                      <Unread unread={dialog.unread}/>
                    </Link>
                  </li>
                {/each}
              </ul>
            </li>
          {/each}
        </ul>

        <h2>{l('Private dialogs')}</h2>
        <ul class="sidebar__nav__servers for-private-dialogs">
          {#each $connectionsWithChannels as connection}
            {#if connection.private.length}
              <li>
                <Link href="/chat/{connection.connection_id}" className="is-heading">{l(connection.name)}</Link>
                <ul class="sidebar__nav__conversations is-private">
                  {#each connection.private as dialog}
                    <li>
                      <Link href="/chat/{connection.connection_id}/{dialog.path}">
                        <span>{dialog.name}</span>
                        <Unread unread={dialog.unread}/>
                      </Link>
                    </li>
                  {/each}
                </ul>
              </li>
            {/if}
          {/each}
        </ul>
      {/if}

      <h2>{$email || l('Account')}</h2>
      <Link href="/join" className="sidebar__nav__join"><Icon name="user-plus"/> {l('Join dialog...')}</Link>
      <Link href="/connections" className="sidebar__nav__connections"><Icon name="network-wired"/> {l('Add connection...')}</Link>
      <Link href="/settings" className="sidebar__nav__settings"><Icon name="cog"/> {l('Settings')}</Link>
      <Link href="/help" className="sidebar__nav__help"><Icon name="question-circle"/> {l('Help')}</Link>
      <Link href="/logout" className="sidebar__nav__logout"><Icon name="power-off"/> {l('Log out')}</Link>
    </nav>
  </div>
</div>
