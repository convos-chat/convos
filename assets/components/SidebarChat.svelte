<script>
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import TextField from './form/TextField.svelte';
import {activeMenu, container, gotoUrl} from '../store/router';
import {fly} from 'svelte/transition';
import {getContext} from 'svelte';
import {l, topicOrStatus} from '../js/i18n';
import {q, regexpEscape, tagNameIs} from '../js/util';

const user = getContext('user');
const notifications = $user.notifications;

let activeLinkIndex = 0;
let filter = '';
let navEl;
let searchHasFocus = false;
let visibleLinks = [];

$: flyTransitionParameters = {duration: $container.small ? 250 : 0, x: $container.width};
$: filterNav({filter, type: 'change'}); // Passing "filter" in to make sure filterNav() is called on change
$: if (visibleLinks[activeLinkIndex]) visibleLinks[activeLinkIndex].classList.add('has-focus');

function clearFilter() {
  searchHasFocus = false;
  setTimeout(() => {filter = ''}, 100);
}

function dialogClassNames(connection, dialog) {
  const cn = [dialog.dialog_id ? 'for-dialog' : 'for-connection'];
  if (dialog.frozen || connection.state != 'connected') cn.push('is-frozen');
  return cn.join(' ');
}

function filterNav() {
  if (!navEl) return;

  const prefix = filter.match(/^\W+/) ? '' : '\\b\\W*';
  const filterRe = new RegExp(prefix + regexpEscape(filter), 'i');
  const hasVisibleLinks = {};
  const seen = {};

  activeLinkIndex = 0;
  searchHasFocus = true;
  visibleLinks = [];

  // Show and hide navigation links
  q(navEl, 'a', (aEl, i) => {
    const aClassList = aEl.classList;
    if (!filter.length && aClassList.contains('has-path')) activeLinkIndex = i;
    aClassList.remove('has-focus');

    const makeVisible = !filter.length || !seen[aEl.href] && aEl.textContent.match(filterRe);
    if (makeVisible) visibleLinks.push(aEl);
    makeVisible ? aEl.removeAttribute('hidden') : aEl.setAttribute('hidden', '');
    seen[aEl.href] = true;
  });

  // Show connections
  q(navEl, '.for-connection', connEl => {
    let el = connEl;
    while ((el = el.nextElementSibling)) {
      if (!el.classList.contains('for-dialog')) break;
      if (el.hasAttribute('hidden')) continue;
      return connEl.removeAttribute('hidden');
    }
  });

  // Show headings
  q(navEl, 'h3', h3 => {
    let el = h3;
    while ((el = el.nextElementSibling)) {
      if (tagNameIs(el, 'h3')) break;
      if (el.hasAttribute('hidden')) continue;
      return h3.removeAttribute('hidden');
    }

    h3.setAttribute('hidden', '');
  });
}

function onNavItemClicked(e) {
  const className = e.target.className || '';
  if (className.match(/network|user/)) setTimeout(() => { $activeMenu = 'settings' }, 50);
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

function renderUnread(dialog) {
  return dialog.unread > 60 ? '60+' : dialog.unread || 0;
}
</script>

{#if $activeMenu == 'nav' || !$container.small}
  <div class="sidebar-left" transition:fly="{flyTransitionParameters}">
    <form class="sidebar__header" on:submit="{e => e.preventDefault()}">
      <input type="text" id="sidebar_left_search_input"
        placeholder="{searchHasFocus ? l('Search...') : l('Convos')}"
        bind:value="{filter}"
        on:blur="{clearFilter}"
        on:focus="{filterNav}"
        on:keydown="{onSearchKeydown}">
      <label for="sidebar_left_search_input"><Icon name="search"/></label>
    </form>

    <nav class="sidebar-left__nav" class:is-filtering="{filter.length > 0}" bind:this="{navEl}" on:click="{onNavItemClicked}">
      <h3>{l('Conversations')}</h3>
      {#each $user.connections.toArray() as connection}
        <Link href="{connection.path}" class="{dialogClassNames(connection, connection)}" title="{topicOrStatus(connection, connection)}">
          <Icon name="network-wired"/>
          <span>{connection.name}</span>
          <b class="unread" hidden="{!connection.unread}">{renderUnread(connection)}</b>
        </Link>
        {#each connection.dialogs.toArray() as dialog}
          <Link href="{dialog.path}" class="{dialogClassNames(connection, dialog)}" title="{topicOrStatus(connection, dialog)}">
            <Icon name="{dialog.is_private ? 'user' : 'user-friends'}"/>
            <span>{dialog.name}</span>
            <b class="unread" hidden="{!dialog.unread}">{renderUnread(dialog)}</b>
          </Link>
        {/each}
      {/each}

      <h3>{$user.email || l('Account')}</h3>
      <Link href="/chat">
        <Icon name="{$notifications.unread ? 'bell' : 'bell-slash'}"/>
        <span>{l('Notifications')}</span>
        <b class="unread" hidden="{!$notifications.unread}">{renderUnread($notifications)}</b>
      </Link>
      <Link href="/add/conversation">
        <Icon name="comment"/>
        <span>{l('Add conversation')}</span>
      </Link>
      <Link href="/add/connection">
        <Icon name="network-wired"/>
        <span>{l('Add connection')}</span>
      </Link>
      <Link href="/settings">
        <Icon name="cog"/>
        <span>{l('Settings')}</span>
      </Link>
      <Link href="/help">
        <Icon name="question-circle"/>
        <span>{l('Help')}</span>
      </Link>
      <Link href="/api/user/logout.html" native="{true}">
        <Icon name="power-off"/>
        <span>{l('Log out')}</span>
      </Link>
    </nav>
  </div>
{/if}
