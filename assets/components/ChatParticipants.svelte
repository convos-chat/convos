<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {afterUpdate, getContext} from 'svelte';
import {l} from '../js/i18n';
import {modeClassNames, q} from '../js/util';

const rtc = getContext('rtc');
const user = getContext('user');

export let dialog;

$: connection = user.findDialog({connection_id: dialog.connection_id});

afterUpdate(() => rtc.render());
</script>

{#if $rtc.localStream.id}
  <div class="rtc-conversations">
    <div class="rtc-conversation is-local has-state-0" data-rtc-id="{rtc.id($rtc.localStream)}">
      <video/>
      <div class="rtc-conversation__actions">
        {#if $rtc.constraints.video}
          <button class="btn rtc-conversation__zoom"><i></i></button>
          <button class="btn rtc-conversation__mute-video"><i></i></button>
        {/if}
        <button class="btn rtc-conversation__hangup"><i></i></button>
        <button class="btn rtc-conversation__mute-audio"><i></i></button>
      </div>
      <p class="rtc-conversation__name"><Icon name="pick:{$connection.nick}" family="solid"/> <span>{$connection.nick}</span></p>
    </div>
    {#each $rtc.peerConnections({remoteStream: true}) as pc}
      <div class="rtc-conversation is-remote has-state-0" data-rtc-id="{rtc.id(pc)}">
        <video/>
        <div class="rtc-conversation__actions">
          {#if $rtc.constraints.video}
            <button class="btn rtc-conversation__zoom"><i></i></button>
            <button class="btn rtc-conversation__mute-video" disabled="{true}"><i></i></button>
          {/if}
          <button class="btn rtc-conversation__mute-audio" disabled="{true}"><i></i></button>
        </div>
        <p class="rtc-conversation__name"><Icon name="pick:{pc.target.toLowerCase()}" family="solid"/> <span>{pc.target}</span></p>
      </div>
    {/each}
  </div>
{/if}

{#if dialog.participants().length}
  <div class="sidebar-right">
    <nav class="sidebar-right__nav">
      <h3>{l('Participants (%1)', dialog.participants().length)}</h3>
      {#each dialog.participants() as participant}
        <Link href="/chat/{dialog.connection_id}/{participant.id}" class="participant {modeClassNames(participant.modes)}">
          <Icon name="pick:{participant.id}" family="solid" color="{participant.color}"/>
          <span>{participant.nick}</span>
        </Link>
      {/each}
    <nav>
  </div>
{/if}
