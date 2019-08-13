<script>
import {getContext} from 'svelte';
import {gotoUrl} from '../store/router';
import {l} from '../js/i18n';
import {q, tagNameIs} from '../js/util';
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import StateIcon from '../components/StateIcon.svelte';
import TextField from './form/TextField.svelte';
import Unread from './Unread.svelte';

export let visible = false;

const user = getContext('user');

let activeLinkIndex = 0;
let filter = '';
let navEl;
let searchInput;
let visibleLinks = [];

function clearFilter() {
  setTimeout(() => {filter = ''}, 100);
}

function filterNav(filter) {
  if (!navEl) return;

  const filterRe = new RegExp('\\b\\W*' + filter, 'i');
  const hasVisibleLinks = {};
  const seen = {};

  activeLinkIndex = 0;
  visibleLinks = [];

  // Show and hide navigation links
  q(navEl, 'a', (aEl, i) => {
    const aClassList = aEl.classList;
    const makeVisible = !filter.length || !seen[aEl.href] && aEl.textContent.match(filterRe);
    const parentList = aEl.closest('.sidebar__nav__account, .sidebar__nav__servers');

    if (makeVisible) {
      if (parentList) hasVisibleLinks[parentList.className] = parentList;
      visibleLinks.push(aEl);
    }

    if (!filter.length && aClassList.contains('has-path')) {
      activeLinkIndex = i;
    }

    aClassList[makeVisible ? 'remove' : 'add']('hide');
    aClassList.remove('has-focus');
    seen[aEl.href] = true;
  });

  // Show and hide navigation headings
  q(navEl, 'ul', listEl => {
    const makeVisible = hasVisibleLinks[listEl.className] || false;
    const headingEl = listEl.previousElementSibling;
    if (headingEl && tagNameIs(headingEl, 'h2')) headingEl.classList[makeVisible ? 'remove' : 'add']('hide');
  });
}

function onGlobalKeydown(e) {
  if (e.shiftKey && e.keyCode == 13) { // Shift+Enter
    e.preventDefault();
    const targetEl = document.activeElement || searchInput;
    if (targetEl == searchInput || tagNameIs(targetEl, 'body')) {
      searchInput.focus(); // TODO: Focus chat text input
    }
    else {
      searchInput.focus();
    }
  }
}

function onSearchKeydown(e) {
  // Go to the active link when Enter is pressed
  if (e.keyCode == 13) {
    e.preventDefault();
    clearFilter();
    if (visibleLinks[activeLinkIndex]) gotoUrl(visibleLinks[activeLinkIndex].href);
    return;
  }

  // Move focus from/to a given navigation link
  // TODO: Add support for j/k, with some sort of additional combination
  // Currently only Up/Down array keys will update the focused link
  const moveBy = e.keyCode == 38 ? -1 : e.keyCode == 40 ? 1 : 0;
  if (moveBy) {
    e.preventDefault();
    if (visibleLinks[activeLinkIndex]) visibleLinks[activeLinkIndex].classList.remove('has-focus');
    activeLinkIndex += e.ctrlKey ? moveBy * 4 : moveBy;
  }

  // Make sure we do not try to focus a link that is not visible
  if (activeLinkIndex < 0) activeLinkIndex = visibleLinks.length - 1;
  if (activeLinkIndex >= visibleLinks.length) activeLinkIndex = 0;
}

$: filterNav(encodeURIComponent(filter));
$: if (visibleLinks[activeLinkIndex]) visibleLinks[activeLinkIndex].classList.add('has-focus');
$: connections = $user.connections;
</script>

<svelte:window on:keydown="{onGlobalKeydown}"/>

<div class="sidebar-wrapper {visible ? 'is-visible' : ''}">
  <div class="sidebar is-chatting">
    <form class="sidebar__search">
      <input type="text"
        placeholder="{l('Convos')}"
        bind:this="{searchInput}"
        bind:value="{filter}"
        on:blur="{clearFilter}"
        on:focus="{filterNav}"
        on:keydown="{onSearchKeydown}">
      <Icon name="search" on:click="{() => searchInput.focus()}"/>
    </form>

    <nav class="sidebar__nav" class:is-filtering="{filter.length > 0}" bind:this="{navEl}">
      {#if connections.length}
        <h2>{l('Group conversations')}</h2>
        <ul class="sidebar__nav__servers for-group-dialogs">
          {#each connections as connection}
            <li>
              <Link href="/chat/{connection.path}">
                {l(connection.name)}
                <StateIcon obj="{connection}"/>
              </Link>

              <ul class="sidebar__nav__conversations is-channels">
                {#each connection.channels as dialog}
                  <li>
                    <Link href="/chat/{dialog.path}">
                      <span>{dialog.name.replace(/^\W/, '')}</span>
                      <Unread unread={dialog.unread}/>
                      <StateIcon obj="{dialog}"/>
                    </Link>
                  </li>
                {/each}
              </ul>
            </li>
          {/each}
        </ul>

        <h2>{l('Private conversations')}</h2>
        <ul class="sidebar__nav__servers for-private-dialogs">
          {#each connections as connection}
            {#if connection.private.length}
              <li>
                <Link href="/chat/{connection.path}">
                  {l(connection.name)}
                  <StateIcon obj="{connection}"/>
                </Link>
                <ul class="sidebar__nav__conversations is-private">
                  {#each connection.private as dialog}
                    <li>
                      <Link href="/chat/{dialog.path}">
                        <span>{dialog.name}</span>
                        <Unread unread={dialog.unread}/>
                        <StateIcon obj="{dialog}"/>
                      </Link>
                    </li>
                  {/each}
                </ul>
              </li>
            {/if}
          {/each}
        </ul>
      {/if}

      <h2>{$user.email || l('Account')}</h2>
      <ul class="sidebar__nav__account">
        <li>
          <Link href="/chat" className="sidebar__nav__notifications">
            <span>{l('Notifications')}</span>
            <Unread unread={user.unread}/>
            <Icon name="{user.unread ? 'bell' : 'bell-slash'}"/>
          </Link>
        </li>
        <li><Link href="/join" className="sidebar__nav__join"><Icon name="user-plus"/> {l('Join conversation...')}</Link></li>
        <li><Link href="/connections" className="sidebar__nav__connections"><Icon name="network-wired"/> {l('Add connection...')}</Link></li>
        <li><Link href="/settings" className="sidebar__nav__settings"><Icon name="cog"/> {l('Settings')}</Link></li>
        <li><Link href="/help" className="sidebar__nav__help"><Icon name="question-circle"/> {l('Help')}</Link></li>
        <li><a href="/logout" className="sidebar__nav__logout" on:click|preventDefault="{e => user.logout.perform()}"><Icon name="power-off"/> {l('Log out')}</a></li>
      </ul>
    </nav>
  </div>
</div>
