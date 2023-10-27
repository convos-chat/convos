<script>
import Icon from './Icon.svelte';
import Link from './Link.svelte';
import escapeRegExp from 'lodash/escapeRegExp';
import {activeMenu, viewport} from '../store/viewport';
import {closestEl, q, settings, tagNameIs} from '../js/util';
import {fly} from 'svelte/transition';
import {getContext, onMount} from 'svelte';
import {l} from '../store/I18N';
import {route} from '../store/Route';
import {slide} from 'svelte/transition';

export let transition;

const user = getContext('user');
const notifications = user.notifications;

let activeLinkIndex = 0;
let filter = '';
let navEl;
let searchHasFocus = false;
let visibleLinks = [];
let collapsedStates = JSON.parse(localStorage.getItem('collapsedStates') || '{}');

$: filterNav({filter}); // Passing "filter" in to make sure filterNav() is called on change
$: addConversationLink = '/settings/conversation?connection_id=' + ($user.activeConversation.connection_id || '');
$: duration = searchHasFocus ? 0 : 250;
$: searchQuery = filter.replace(/^\//, '');
$: if (navEl) clearFilter($route);
$: if (visibleLinks[activeLinkIndex]) visibleLinks[activeLinkIndex].classList.add('has-focus');

onMount(() => {
  return route.on('update', (attrs) => attrs.path && activeMenu.set(''));
});

function clearFilter() {
  q(navEl, 'a', aEl => aEl.classList.remove('has-focus'));

  setTimeout(() => {
    if (!navEl) return;
    filter = '';
    const el = document.activeElement;
    if (el && closestEl(el, navEl)) q(navEl, 'a.has-path', aEl => aEl.focus());
  }, 100);
}

function conversationClassNames(connection, conversation) {
  const cn = [conversation.conversation_id ? 'for-conversation' : 'for-connection'];
  if (conversation.frozen || connection.state !== 'connected') cn.push('is-frozen');
  if (conversation.frozen) cn.push('has-tooltip');
  return cn.join(' ');
}

function filterNav() {
  if (!navEl) return;

  activeLinkIndex = 0;
  visibleLinks = [];

  const prefix = [filter.match(/^\W+/) ? '' : '\\b\\W*'];
  if (prefix[0]) prefix.push('');

  // Show and hide navigation links
  for (let p = 0; p < prefix.length; p++) {
    const filterRe
      = filter === '+' ? new RegExp(/[1-9]\d*\+?\s*$/)
      : filter === '+@' ? new RegExp(/^\s*\w.*[1-9]\d*\+?\s*$/)
      : filter === '+#' ? new RegExp(/^\s*#.*[1-9]\d*\+?\s*$/)
      : new RegExp(prefix[p] + escapeRegExp(filter), 'i');

    const seen = {};
    q(navEl, 'a', (aEl, i) => {
      const aClassList = aEl.classList;
      if (!filter.length && aClassList.contains('has-path')) activeLinkIndex = i;
      aClassList.remove('has-focus');

      const makeVisible = !filter.length || (!aEl.href.match(/\/search$/) && !seen[aEl.href] && aEl.textContent.match(filterRe));
      if (makeVisible) visibleLinks.push(aEl);
      aEl.classList[makeVisible ? 'remove' : 'add']('hidden');
      seen[aEl.href] = true;
    });

    if (visibleLinks.length) break;
  }

  // Allow search in chat history
  const searchEl = navEl.querySelector('.for-search');
  searchEl.classList[filter ? 'remove' : 'add']('hidden');
  if (!searchEl.classList.contains('hidden')) visibleLinks.push(searchEl);

  // Show headings
  q(navEl, 'h3', h3 => {
    let el = h3;
    while ((el = el.nextElementSibling)) {
      if (tagNameIs(el, 'h3')) break;
      if (!el.classList.contains('hidden')) return h3.classList.remove('hidden');
    }

    h3.classList.add('hidden');
  });
}

function onBlur() {
  searchHasFocus = false;
  if (filter.indexOf('+') !== 0) clearFilter();
}

function onFocus() {
  searchHasFocus = true;
}

function onSearchKeydown(e) {
  // Go to the active link when Enter is pressed
  if (e.key == 'Enter') {
    e.preventDefault();
    clearFilter();
    if (visibleLinks[activeLinkIndex]) route.go(visibleLinks[activeLinkIndex].href);
    return;
  }

  // Move focus from/to a given navigation link
  // TODO: Add support for j/k, with some sort of additional combination
  // Currently only Up/Down array keys will update the focused link
  const moveBy = e.key == 'ArrowUp' ? -1 : e.key == 'ArrowDown' ? 1 : 0;
  if (moveBy) {
    e.preventDefault();
    if (visibleLinks[activeLinkIndex]) visibleLinks[activeLinkIndex].classList.remove('has-focus');
    activeLinkIndex += e.ctrlKey ? moveBy * 4 : moveBy;
  }

  // Make sure we do not try to focus a link that is not visible
  if (activeLinkIndex < 0) activeLinkIndex = visibleLinks.length - 1;
  if (activeLinkIndex >= visibleLinks.length) activeLinkIndex = 0;
}

function renderUnread(conversation, max = 60) {
  return conversation.unread > max ? (max + '+') : conversation.unread || 0;
}

function toggleSection(connection_id) {
  collapsedStates[connection_id] = !collapsedStates[connection_id];
  localStorage.setItem('collapsedStates', JSON.stringify(collapsedStates));
}
</script>

<style lang="scss">
.header-wrapper {
  background: var(--sidebar-left-bg);
  position: sticky;
  left: 0;
  z-index: 2;
}

.tooltip {
  right: 0;
}

[href="#toggle"] {
  :global(i) {
    transition: transform 150ms linear;
  }

  &.collapsed :global(i) {
    transform: rotate(180deg);
  }
}

nav :global(a.for-search),
.collapsible :global(a) {
  padding-left: 0.5em;
  padding-right: 2px;
  display: flex;

  :global(.name) {
    overflow: hidden;
    text-overflow: ellipsis;
    flex-grow: 1;
    padding-inline: 0.4rem;
  }
}
</style>

<div class="sidebar-left" transition:fly="{transition}">
  {#if !viewport.isSingleColumn}
    <div class="header-wrapper">
      <form class="sidebar-header" class:has-focus="{searchHasFocus}" on:submit="{e => e.preventDefault()}">
        <input type="text" id="search_input" class="is-primary-menu-item"
          placeholder="{searchHasFocus ? $l('Search...') : $l('Convos')}"
          bind:value="{filter}"
          on:blur="{onBlur}"
          on:focus="{onFocus}"
          on:keydown="{onSearchKeydown}">
        <label for="search_input" class="btn-hallow"><Icon name="search"/></label>
        <Link href="/chat" class="btn-hallow for-notifications">
          <Icon family="regular" name="bell"/>
          <small class="badge is-important" hidden="{!$notifications.unread}">{renderUnread($notifications)}</small>
        </Link>
      </form>
    </div>
  {/if}

  <nav class="sidebar-left__nav" class:is-filtering="{filter.length > 0}" bind:this="{navEl}">
    <h3 hidden={filter.length > 0}>{$l('Conversations')}</h3>
    {#if !$user.connections.size}
      <Link href="/settings/connections">
        <Icon name="exclamation-circle"/>
        <span>{$l('No conversations')}</span>
      </Link>
    {/if}
    {#each $user.connections.toArray() as connection}
      <a href="#toggle" on:click|preventDefault={() => toggleSection(connection.connection_id)}
        hidden={filter.length > 0}
        class:collapsed={collapsedStates[connection.connection_id]}>
        <Icon name="chevron-up"/>
        <span>{connection.name || connection.connection_id}</span>
      </a>
      {#if !collapsedStates[connection.connection_id] || filter.length}
        <div class="collapsible" transition:slide={{duration}}>
          <Link href="{connection.path}" class="{conversationClassNames(connection, connection)}">
            <Icon name="network-wired"/>
            <span class="name">{filter.length > 0 ? connection.name : $l('Server')}</span>
            <span class="tooltip">{$l(connection.frozen)}</span>
            <span class="badge" hidden="{!connection.unread}">{renderUnread(connection)}</span>
          </Link>
          {#each connection.conversations.toArray() as conversation}
            <Link href="{conversation.path}" class="{conversationClassNames(connection, conversation)}">
              {#if conversation.frozen && !conversation.is('private')}
                <Icon name="exclamation-triangle"/>
              {:else}
                <Icon name="{conversation.is('private') ? 'user' : 'user-friends'}"/>
              {/if}
              <span class="name">{conversation.name}</span>
              <span class="tooltip">{$l(conversation.frozen)}</span>
              <span class="badge" class:is-important={!!conversation.notifications} hidden="{!conversation.unread}">{renderUnread(conversation)}</span>
            </Link>
          {/each}
        </div>
      {/if}
    {/each}

    <h3 hidden={filter.length > 0}>{$l('Settings')}</h3>
    <a href="#toggle" on:click|preventDefault={() => toggleSection('settings')}
      hidden={filter.length > 0}
      class:collapsed={collapsedStates.settings}><Icon name="chevron-up"/>
      <span>{$user.email}</span>
    </a>
    {#if !collapsedStates.settings && !filter.length}
      <div class="collapsible" transition:slide={{duration}}>
        <Link href="/chat">
          <Icon name="bell"/>
          <span class="name">{$l('Notifications')}</span>
          <span class="badge" hidden="{!$notifications.unread}">{renderUnread($notifications)}</span>
        </Link>
        <Link href="/search">
          <Icon name="search"/>
          <span class="name">{$l('Search')}</span>
        </Link>
        <Link href="{addConversationLink}">
          <Icon name="comment"/>
          <span class="name">{$l('Add conversation')}</span>
        </Link>
        <Link href="/settings/connections">
          <Icon name="network-wired"/>
          <span class="name">{$l('Connections')}</span>
        </Link>
        <Link href="/settings/account">
          <Icon name="user-cog"/>
          <span class="name">{$l('Account')}</span>
        </Link>
        <Link href="/settings/files">
          <Icon name="folder-open"/>
          <span class="name">{$l('Files')}</span>
        </Link>
        {#if $user.is('admin')}
          <Link href="/settings">
            <Icon name="tools"/>
            <span class="name">{$l('Settings')}</span>
          </Link>
          <Link href="/settings/users">
            <Icon name="users"/>
            <span class="name">{$l('Users')}</span>
          </Link>
        {/if}
        <Link href="/help">
          <Icon name="question-circle"/>
          <span class="name">{$l('Help')}</span>
        </Link>
        <a href="{route.urlFor('/logout')}?csrf={settings('csrf')}" target="_self">
          <Icon name="power-off"/>
          <span class="name">{$l('Log out')}</span>
        </a>
      </div>
    {/if}
    <Link href="/search?q={encodeURIComponent(searchQuery)}" class="for-search hidden">
      <Icon name="search"/>
      <span class="name">{$l('Search for "%1"', searchQuery)}</span>
    </Link>
  </nav>
</div>
