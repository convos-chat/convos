<script>
import Icon from './Icon.svelte';
import SidebarItem from '../components/SidebarItem.svelte';
import TextField from './form/TextField.svelte';
import Unread from './Unread.svelte';
import {closestEl, q, regexpEscape, tagNameIs} from '../js/util';
import {getContext, onMount} from 'svelte';
import {activeMenu, gotoUrl} from '../store/router';
import {l} from '../js/i18n';

const user = getContext('user');
const connections = user.connections;
const notifications = user.notifications;

let activeLinkIndex = 0;
let filter = '';
let navEl;
let searchHasFocus = false;
let searchInput;
let visibleLinks = [];

$: filterNav({filter, type: 'change'}); // Passing "filter" in to make sure filterNav() is called on change

$: if (visibleLinks[activeLinkIndex]) visibleLinks[activeLinkIndex].classList.add('has-focus');

onMount(() => {
  document.addEventListener('click', hideMenu);
  return () => document.removeEventListener('click', hideMenu);
});

function clearFilter() {
  searchHasFocus = false;
  setTimeout(() => {filter = ''}, 100);
}

function filterNav() {
  if (!navEl) return;

  const filterRe = new RegExp('\\b\\W*' + regexpEscape(filter), 'i');
  const hasVisibleLinks = {};
  const seen = {};

  activeLinkIndex = 0;
  searchHasFocus = true;
  visibleLinks = [];

  // Show and hide navigation links
  q(navEl, '.sidebar__item__link', (aEl, i) => {
    const aClassList = aEl.classList;
    if (!filter.length && aClassList.contains('has-path')) activeLinkIndex = i;
    aClassList.remove('has-focus');

    const listItem = aEl.parentNode;
    const makeVisible = !filter.length || !seen[aEl.href] && aEl.textContent.match(filterRe);
    if (makeVisible) visibleLinks.push(aEl);
    makeVisible ? listItem.removeAttribute('hidden') : listItem.setAttribute('hidden', '');
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

function hideMenu(e) {
  if (closestEl(e.target, '.chat-header')) return;
  if (closestEl(e.target, '.sidebar-wrapper')) return;
  $activeMenu = '';
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
</script>

<svelte:window on:keydown="{onGlobalKeydown}"/>

<div class="sidebar-wrapper {$activeMenu ? 'is-visible' : ''}">
  <div class="sidebar is-chatting">
    <form class="sidebar__header">
      <input type="text"
        placeholder="{searchHasFocus ? l('Search...') : l('Convos')}"
        bind:this="{searchInput}"
        bind:value="{filter}"
        on:blur="{clearFilter}"
        on:focus="{filterNav}"
        on:keydown="{onSearchKeydown}">
      <Icon name="search" on:click="{() => searchInput.focus()}"/>
    </form>

    <nav class="sidebar__nav" class:is-filtering="{filter.length > 0}" bind:this="{navEl}">
      {#if $connections.length}
        <h3>{l('Group conversations')}</h3>
        {#each $connections.all() as connection}
          <SidebarItem dialog="{connection}"/>
          {#each connection.publicDialogs as dialog}
            <SidebarItem {dialog}/>
          {/each}
        {/each}

        <h3>{l('Private conversations')}</h3>
        {#each $connections.all() as connection}
          {#if connection.privateDialogs.length}
            <SidebarItem dialog="{connection}"/>
            {#each connection.privateDialogs as dialog}
              <SidebarItem {dialog}/>
            {/each}
          {/if}
        {/each}
      {/if}

      <h3>{$user.email || l('Account')}</h3>
      <SidebarItem href="/chat" icon="{$notifications.unread ? 'bell' : 'bell-slash'}">
        <span>{l('Notifications')}</span>
        <Unread unread="{$notifications.unread}"/>
      </SidebarItem>
      <SidebarItem href="/add/conversation" icon="comment">
        <span>{l('Add conversation')}</span>
      </SidebarItem>
      <SidebarItem href="/add/connection" icon="network-wired">
        <span>{l('Add connection')}</span>
      </SidebarItem>
      <SidebarItem href="/settings" icon="cog">
        <span>{l('Settings')}</span>
      </SidebarItem>
      <SidebarItem href="/help" icon="question-circle">
        <span>{l('Help')}</span>
      </SidebarItem>
      <SidebarItem href="/logout" icon="power-off">
        <span>{l('Log out')}</span>
      </SidebarItem>
    </nav>
  </div>
</div>
