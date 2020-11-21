<script>
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import {afterUpdate, getContext} from 'svelte';
import {l} from '../js/i18n';
import {modeClassNames, q} from '../js/util';

const rtc = getContext('rtc');
const user = getContext('user');

export let conversation;

$: connection = user.findConversation({connection_id: conversation.connection_id});

afterUpdate(() => rtc.render());

function joinConversation(e, participant) {
  e.preventDefault();
  conversation.send('/join ' + participant.id);
}
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
      <span class="rtc-conversation__name"><Icon name="pick:{$connection.nick}" family="solid"/> <span>{$connection.nick}</span></span>
    </div>
    {#each $rtc.peerConnections({remoteStream: true}) as pc}
      <div class="rtc-conversation is-remote has-state-0" data-rtc-id="{rtc.id(pc)}">
        <video/>
        <pre class="rtc-conversation__info" hidden>Received: {pc.info.bytesReceived} B
Sent: {pc.info.bytesSent} B
Signalling state: {l(pc.info.signalingState || 'unknown')}
ICE connection state: {l(pc.info.iceConnectionState || 'unknown')}
ICE gathering state: {l(pc.info.iceGatheringState || 'unknown')}
Local address: {pc.info.localAddress || '0.0.0.0'}
Remote address: {pc.info.remoteAddress || '0.0.0.0'}

Video:
  Framerate: {Math.round(pc.info.audio.outbound.framerateMean || 0)}/{Math.round(pc.info.video.inbound.framerateMean || 0)}
  Jitter: {pc.info.audio.inbound.jitter || 0}
  Sent: {pc.info.audio.outbound.packetsSent || 0}
  Received: {pc.info.audio.inbound.packetsReceived || 0}
  Discarded: {pc.info.audio.inbound.discardedPackets || 0}
  Dropped: {pc.info.audio.outbound.droppedFrames || 0}
  Lost: {pc.info.audio.inbound.packetsLost || 0}

Audio:
  Framerate: {Math.round(pc.info.video.outbound.framerateMean || 0)}/{Math.round(pc.info.video.inbound.framerateMean || 0)}
  Jitter: {pc.info.video.inbound.jitter || 0}
  Sent: {pc.info.video.outbound.packetsSent || 0}
  Received: {pc.info.video.inbound.packetsReceived || 0}
  Discarded: {pc.info.video.inbound.discardedPackets || 0}
  Dropped: {pc.info.video.outbound.droppedFrames || 0}
  Lost: {pc.info.video.inbound.packetsLost || 0}</pre>
        <div class="rtc-conversation__actions">
          {#if $rtc.constraints.video}
            <button class="btn rtc-conversation__zoom"><i></i></button>
            <button class="btn rtc-conversation__mute-video" disabled="{true}"><i></i></button>
          {/if}
          <button class="btn rtc-conversation__mute-audio" disabled="{true}"><i></i></button>
        </div>
        <a href="#info" class="rtc-conversation__name"><Icon name="pick:{pc.target.toLowerCase()}" family="solid"/> <span>{pc.target}</span></a>
      </div>
    {/each}
  </div>
{/if}

{#if conversation.participants().length}
  <div class="sidebar-right">
    <nav class="sidebar-right__nav">
      <h3>{l('Participants (%1)', conversation.participants().length)}</h3>
      {#each conversation.participants() as participant}
        <Link href="/chat/{conversation.connection_id}/{participant.id}" on:click="{e => joinConversation(e, participant)}" class="participant {modeClassNames(participant.modes)}">
          <Icon name="pick:{participant.id}" family="solid" color="{participant.color}"/>
          <span>{participant.nick}</span>
        </Link>
      {/each}
    <nav>
  </div>
{/if}
