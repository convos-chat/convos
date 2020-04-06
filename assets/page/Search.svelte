<script>
import ChatMessages from '../components/ChatMessages.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import Icon from '../components/Icon.svelte';
import {focusMainInputElements} from '../js/util';
import {getContext, onMount} from 'svelte';
import {l} from '../js/i18n';
import {route} from '../store/Route';

const user = getContext('user');
const search = user.search;

let chatInput;

onMount(() => {
  load(route, {query: true});
  return route.on('update', load);
});

function load(route, changed) {
  const match = route.param('q');
  if (!changed.query || typeof match != 'string') return;
  chatInput.setValue(match);
  search.load({match});
  focusMainInputElements('chat_input');
  route.update({title: l('Search for "%1"', match)});
}
</script>

<ChatHeader>
  <h1><a href="#activeMenu:nav" tabindex="-1"><Icon name="search"/><span>{l('Search')}</span></a></h1>
</ChatHeader>

<main class="main">
  <div class="messages-container" class:has-notifications="{$search.messages.length}">
    <ChatMessages connection="{user}" dialog="{search}" input="{null}"/>
  </div>
</main>

<ChatInput dialog="{search}" bind:this="{chatInput}"/>
