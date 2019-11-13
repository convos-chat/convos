<script>
import ChatHeader from '../components/ChatHeader.svelte';
import {commands} from '../js/autocomplete';
import {emojiAliases} from '../js/md';
import {getContext} from 'svelte';
import {l, lmd} from '../js/i18n';

const settings = getContext('settings');
</script>

<ChatHeader>
  <h1>{l('Help')}</h1><small>v{settings.version}</small>
</ChatHeader>

<main class="main">
  <p>
    {@html lmd('Got any questions? Come and talk to us in the "#convos" channel on https://freenode.net.')}
    {@html lmd('More information can also be found on https://convos.by.')}
  </p>

  <h2>{l('Shortcuts')}</h2>
  <dl>
    <dt>{l('shift+enter')}</dt>
    <dd>{l('Shift focus between chat input and search in sidebar.')}</dd>
  </dl>

  <h2>{l('Autocomplete')}</h2>
  <p>{l('The following rules apply when typing a message:')}</p>
  <dl>
    <dt>@nick</dt><dd>{l('"@" followed by a character will show matching nicks in the current conversation.')}</dd>
    <dt>:emoji_name</dt><dd>{l('":" followed by a character will show matching emojis.')}</dd>
    <dt>/command</dt><dd>{l('"/" will show the available commands.')}</dd>
    <dt>#conversation</dt><dd>{l('"#" will show the matching conversation names.')}</dd>
  </dl>

  <h2>{l('Text formatting')}</h2>
  <p>{l('Convos supports some special way of formatting text:')}</p>
  <dl>
    <dt>{Object.keys(emojiAliases).sort().map(k => emojiAliases[k]).join(', ')}</dt>
    <dd>{l('Will be automatically converted into emojis.')}</dd>
    <dt>{l('> some text')}</dt>
    <dd>{l('A line starting with ">" will be converted into a quote.')}</dd>
    <dt>{l('_some text_, __some text__, ___some text___')}</dt>
    <dd>{@html lmd('Using "\_" around some text, will convert it into _italic_, __bold__ or ___italic bold___.')}</dd>
    <dt>{l('`some fragment`')}</dt>
    <dd>{@html lmd('Using backticks around some text, will format it as a `code fragment`.')}</dd>
    <dt>https://...</dt>
    <dd>{l('URLs will be converted to links, and might be embedded in the chat.')}</dd>
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
    <li><a href="https://convos.by" target="_blank">{l('Project homepage')}</a></li>
    <li><a href="https://github.com/Nordaaker/convos/issues" target="_blank">{l('Bug/issue tracker')}</a></li>
    <li><a href="https://github.com/Nordaaker/convos" target="_blank">{l('Source code')}</a></li>
  </ul>
</main>
