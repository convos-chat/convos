<script>
import ChatHeader from '../components/ChatHeader.svelte';
import Icon from '../components/Icon.svelte';
import InfinityScroll from '../components/InfinityScroll.svelte';
import Link from '../components/Link.svelte';
import {conversationUrl} from '../js/chatHelpers';
import {getContext, onMount} from 'svelte';
import {nbsp} from '../js/util';
import {l} from '../store/I18N';

export const title = 'Notifications';

const user = getContext('user');
const notifications = user.notifications;

$: classNames = ['main', messages.length && 'has-results'].filter(i => i);
$: messages = $notifications.messages;

onMount(async () => {
  await notifications.load();
  await notifications.markAsRead();
});
</script>

<style lang="scss">
.message a {
  text-decoration: none;
  display: block;

  &:focus,
  &:hover {
    background: var(--body-bg);
    filter: brightness(0.95);
  }
}
</style>

<ChatHeader>
  <h1>{$l('Notifications')}</h1>
  <Link href="/settings/account" class="btn-hallow"><Icon name="user-cog"/></Link>
</ChatHeader>

<InfinityScroll class="{classNames.join(' ')}" on:rendered="{e => e.detail.scrollTo(-1)}">
  {#if $messages.length === 0 && !notifications.is('loading')}
    <h2>{$l('No notifications.')}</h2>
  {/if}

  {#each $messages.render() as message, i}
    {#if !i || message.dayChanged}
      <div class="message__status-line for-day-changed"><span><Icon name="calendar-alt"/> <i>{message.ts.getHumanDate()}</i></span></div>
    {/if}

    <div class="{message.className}">
      <Icon name="pick:{message.from}" color="{message.color}"/>
      <span class="message__from" style="color:{message.color}" tabindex="-1">{message.from}</span>
      <a href={conversationUrl(message)}>
        <div class="message__ts has-tooltip">
          <span>{message.ts.format('%H:%M')}</span>
          <span class="tooltip">{nbsp(message.ts.toLocaleString())}</span>
        </div>
        {@html message.html}
      </a>
    </div>
  {/each}

  {#if $notifications.is('loading')}
    <div class="message__status-line for-loading"><span><Icon name="spinner" animation="spin"/> <i>{$l('Loading...')}</i></span></div>
  {/if}
</InfinityScroll>
