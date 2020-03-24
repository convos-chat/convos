<script>
import ChatMessages from '../components/ChatMessages.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import Dialog from '../store/Dialog';
import Icon from '../components/Icon.svelte';
import {getContext, onMount} from 'svelte';
import {l} from '../js/i18n';

const user = getContext('user');
const search = user.search;

let chatInput;

onMount(() => {
  search.load({});
});
</script>

<ChatHeader>
  <h1><a href="#activeMenu:nav}" tabindex="-1"><Icon name="search"/><span>{l('Search')}</span></a></h1>
</ChatHeader>

<main class="main">
  <div class="messages-container" class:has-notifications="{$search.messages.length}">
    <ChatMessages connection="{user}" dialog="{search}" input="{null}"/>
  </div>
</main>

<ChatInput dialog="{search}" bind:this="{chatInput}"/>
