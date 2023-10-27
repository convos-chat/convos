<script>
import Icon from '../components/Icon.svelte';
import {activeMenu} from '../store/viewport';
import {l} from '../store/I18N';
import {userGroupHeadings} from '../js/constants';

export let conversation;

$: participants = conversation.participants;

function navItems($participants) {
  const items = [];
  let lastGroup = -1;

  for (const p of $participants) {
    if (lastGroup != p.group) items.push({heading: userGroupHeadings[p.group] || userGroupHeadings[0]});
    lastGroup = p.group;
    items.push(p);
  }

  return items;
}
</script>

<nav class="participants">
  {#if $participants.length}
    {#each navItems($participants.toArray()) as item}
      {#if item.heading}
        <h3>{$l(item.heading)}</h3>
      {:else}
        <a href="#action:join:{item.nick}" class="participant prevent-default">
          <Icon name="pick:{item.nick}" family="solid" color="{item.color}"/>
          <span>{item.nick}</span>
        </a>
      {/if}
    {/each}
  {:else}
    <a href="#settings" on:click="{activeMenu.toggle}"><Icon name="users-cog"/> {$l('Settings')}</a>
  {/if}
</nav>
