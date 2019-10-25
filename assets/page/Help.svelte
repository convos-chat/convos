<script>
import ChatHeader from '../components/ChatHeader.svelte';
import SidebarChat from '../components/SidebarChat.svelte';
import {commands} from '../js/autocomplete';
import {getContext} from 'svelte';
import {l, lmd} from '../js/i18n';

const settings = getContext('settings');
</script>

<SidebarChat/>

<ChatHeader>
  <h1>{l('Help')}</h1><small>v{settings.version}</small>
</ChatHeader>

<main class="main">
  <p>
    {@html lmd('Got any questions? Come and talk to us in the "#convos" channel on http://freenode.net.')}
    {@html lmd('More information can also be found on http://convos.by.')}
  </p>

  <h2>{l('Autocomplete')}</h2>
  <p>{l('The following rules apply when typing a message:')}</p>
  <dl>
    <dt>@nick</dt><dd>{l('"@" followed by a character will show matching nicks in the current conversation.')}</dd>
    <dt>:emoji_name</dt><dd>{l('":" followed by a character will show matching emojis.')}</dd>
    <dt>/command</dt><dd>{l('"/" will show the available commands.')}</dd>
    <dt>#conversation</dt><dd>{l('"#" will show the matching conversation names.')}</dd>
  </dl>

  <h2>{l('Shortcuts')}</h2>
  <dl>
    <dt>{l('shift+enter')}</dt>
    <dd>{l('Shift focus between chat input and search in sidebar.')}</dd>
  </dl>

  <h2>{l('Available commands')}</h2>
  <dl>
    {#each commands as command}
      <dt>{command.example}</dt>
      <dd>{l(command.description)}</dd>
    {/each}
  </dl>

  <h2>{l('Resources')}</h2>
  <ul>
    <li><a href="http://convos.by" target="_blank">{l('Project homepage')}</a></li>
    <li><a href="https://github.com/Nordaaker/convos/issues" target="_blank">{l('Bug/issue tracker')}</a></li>
    <li><a href="https://github.com/Nordaaker/convos" target="_blank">{l('Source code')}</a></li>
  </ul>
</main>
