<script>
import {getContext} from 'svelte';
import {gotoUrl, showMenu} from '../store/router';
import {l} from '../js/i18n';
import {q, tagNameIs} from '../js/util';
import Icon from './Icon.svelte';
import SidebarItem from '../components/SidebarItem.svelte';
import TextField from './form/TextField.svelte';
import Unread from './Unread.svelte';

const user = getContext('user');

let activeLinkIndex = 0;
let filter = '';
let navEl;
let searchHasFocus = false;
let searchInput;
let visibleLinks = [];

function clearFilter() {
  searchHasFocus = false;
  setTimeout(() => {filter = ''}, 100);
}

function filterNav(filter) {
  if (!navEl) return;

  const filterRe = new RegExp('\\b\\W*' + filter, 'i');
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
    makeVisible ? listItem.removeAttribute('hidden') : listItem.setAttribute('hidden', true);

    seen[aEl.href] = true;
  });

  // Show and hide navigation headings
  q(navEl, 'h3', h3 => {
    let el = h3;
    let makeVisible = false;

    while ((el = el.nextElementSibling)) {
      if (tagNameIs(el, 'h3')) break;
      if (el.hasAttribute('hidden')) continue;
      makeVisible = true;
      break;
    }

    makeVisible ? h3.removeAttribute('hidden') : h3.setAttribute('hidden', true);
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

<div class="sidebar-wrapper {$showMenu ? 'is-visible' : ''}">
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
      {#if connections.length}
        <h3>{l('Group conversations')}</h3>
        {#each connections as connection}
          <SidebarItem dialog="{connection}"/>
          {#each connection.channels as dialog}
            <SidebarItem {dialog}/>
          {/each}
        {/each}

        <h3>{l('Private conversations')}</h3>
        {#each connections as connection}
          {#if connection.private.length}
            <SidebarItem dialog="{connection}"/>
            {#each connection.private as dialog}
              <SidebarItem {dialog}/>
            {/each}
          {/if}
        {/each}
      {/if}

      <h3>{$user.email || l('Account')}</h3>
      <SidebarItem href="/chat" icon="{user.unread ? 'bell' : 'bell-slash'}">
        <span>{l('Notifications')}</span>
        <Unread unread="{user.unread}"/>
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
