<script context="module">
import {writable} from '../js/storeGenerator';

const popoverId = writable(null, {
  click(e) {
    e.preventDefault();
    const id = parseInt(e.target.closest('.message').dataset.index, 10);
    this.set(this.get() === id ? -1 : id);
  },
  leave(_e) {
    this.tid = setTimeout(() => this.set(-1), 200);
  },
  enter(e) {
    if (this.tid) clearTimeout(this.tid);
    const id = parseInt(e.target.closest('.message').dataset.index, 10);
    setTimeout(() => this.set(id), 250);
  },
});
</script>

<script>
import Icon from './Icon.svelte';
import {createEventDispatcher} from 'svelte';
import {fade} from 'svelte/transition';
import {l} from '../store/I18N';
import {nbsp, tagNameIs, showFullscreen} from '../js/util';

export let conversation;
export let message;

const dispatch = createEventDispatcher();

let participants = conversation.participants;
let raw = false; // Was messages.raw

function onActionClick(e, aEl) {
  e.preventDefault();
  const action = aEl.hash.match(/action:([a-z]+):(.*)$/) || ['all', 'unknown', 'value'];
  action[2] = decodeURIComponent(action[2]);
  dispatch(action[1], action[2]); // expand, join, mention, whois

  if (action[1] === 'expand') {
    const msg = conversation.messages.get(action[2]);
    msg.expanded = !msg.expanded;
    conversation.messages.update({messages: true});
  }
  else if (['join', 'whois'].indexOf(action[1]) !== -1) {
    conversation.send('/' + action[1] + ' ' + action[2]);
  }
}

function onMessageClick(e) {
  const aEl = e.target.closest('a');
  if (!aEl) return;
  $popoverId = '';

  // #action:x:y links
  if (!aEl.target && aEl.hash.indexOf('action:') !== -1) return onActionClick(e, aEl);

  // Show images in full screen
  if (tagNameIs(e.target, 'img')) return showFullscreen(e, e.target);
  if (aEl.classList.contains('le-thumbnail')) return showFullscreen(e, aEl.querySelector('img'));

  // Proxy video links
  const videoLink = document.querySelector('[target="convos_video"][href="' + aEl.href + '"]');
  if (videoLink) return onVideoLinkClick(e, videoLink); // TODO

  // Make sure embed links are opened in a new tab/window
  if (!aEl.target && aEl.closest('.embed')) aEl.target = '_blank';
  if (aEl.target === '_blank') return;
  e.preventDefault();
}

function renderEmbed(el, embed) {
  const parentNode = embed.nodes[0] && embed.nodes[0].parentNode;
  if (parentNode && parentNode.classList) {
    const method = parentNode.classList.contains('embed') ? 'add' : 'remove';
    parentNode.classList[method]('hidden');
  }

  embed.nodes.forEach(node => el.appendChild(node));
}
</script>

<div class="{message.className}" on:click="{onMessageClick}" class:is-not-present="{!$participants.get(message.from)}" class:is-expanded="{!!message.expanded}" data-index="{message.index}" data-ts="{message.ts.toISOString()}">
  <div class="message__ts has-tooltip">
    <span>{message.ts.format('%H:%M')}</span>
    <span class="tooltip">{nbsp(message.ts.toLocaleString())}</span>
  </div>
  <Icon name="pick:{message.from}" color="{message.color}"/>
  <a href="#popover" on:click="{popoverId.click}"
    on:focus="{popoverId.enter}" on:mouseenter="{popoverId.enter}"
    on:blur="{popoverId.leave}" on:mouseleave="{popoverId.leave}"
    class="message__from" style="color:{message.color}" tabindex="-1">{message.from}</a>
  <div class="message__text">
    {#if message.details}
      <a href="#action:expand:{message.index}"><Icon name="{message.expanded ? 'caret-square-up' : 'caret-square-down'}"/></a>
    {/if}
    {@html message.html}
  </div>
  {#each message.embeds as embedPromise}
    {#await embedPromise}
      <!-- loading embed -->
    {:then embed}
      {#if !raw}
        <div class="embed {embed.className}" use:renderEmbed="{embed}"/>
      {/if}
    {/await}
  {/each}
  {#if $popoverId === message.index}
    <div class="popover" transition:fade="{{duration: 200}}"
      on:focus="{popoverId.enter}" on:mouseenter="{popoverId.enter}"
      on:blur="{popoverId.leave}" on:mouseleave="{popoverId.leave}">
      <a href="#popover" on:click="{popoverId.click}"><Icon name="pick:{message.from}" color="{message.color}"/> {message.from}</a>
      <a href="#action:mention:{encodeURIComponent(message.from)}" class="on-hover"><Icon name="quote-left"/> {$l('Mention')}</a>
      <a href="#action:join:{encodeURIComponent(message.from)}" class="on-hover"><Icon name="comments"/> {$l('Chat')}</a>
      <a href="#action:whois:{encodeURIComponent(message.from)}" class="on-hover"><Icon name="address-card"/> {$l('Whois')}</a>
    </div>
  {/if}
</div>
