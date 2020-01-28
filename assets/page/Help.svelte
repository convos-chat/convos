<script>
import ChatHeader from '../components/ChatHeader.svelte';
import {commands} from '../js/autocomplete';
import {currentUrl, docTitle} from '../store/router';
import {emojiAliases} from '../js/md';
import {getContext} from 'svelte';
import {l, lmd} from '../js/i18n';
import {scrollTo} from '../js/util';

const settings = getContext('settings');

$docTitle = l('%1 - Convos', l('Help'));

$: scrollTo($currentUrl.hash || 0);
</script>

<ChatHeader>
  <h1>{l('Help')}</h1><small>v{settings.version}</small>
</ChatHeader>

<main class="main">
  <p on:click="{scrollTo}">
    {l('Jump to:')}
    <a href="#shortcuts">{l('Shortcuts')}</a>,
    <a href="#autocomplete">{l('Autocomplete')}</a>,
    <a href="#formatting">{l('Text formatting')}</a>,
    <a href="#commands">{l('Available commands')}</a>,
    <a href="#resources">{l('Other resources')}</a>.
  </p>

  <p>
    {@html lmd('Got any questions? Come and talk to us in the "#convos" channel on https://freenode.net.')}
    {@html lmd('More information can also be found on https://convos.by.')}
  </p>

  <h2 id="shortcuts">{l('Shortcuts')}</h2>
  <dl>
    <dt>{l('shift+enter')}</dt>
    <dd>{l('Shift focus between chat input and search in sidebar.')}</dd>
    <dt>{l('Open conversation or connection settings')}</dt>
    <dd>{l('Clicking on the icon next to the conversation name will take you to settings.')}</dd>
  </dl>

  <h2 id="autocomplete">{l('Autocomplete')}</h2>
  <p>{l('The following rules apply when typing a message:')}</p>
  <dl>
    <dt>@nick</dt><dd>{l('"@" followed by a character will show matching nicks in the current conversation.')}</dd>
    <dt>:emoji_name</dt><dd>{l('":" followed by a character will show matching emojis.')}</dd>
    <dt>/command</dt><dd>{l('"/" will show the available commands.')}</dd>
    <dt>#conversation</dt><dd>{l('"#" will show the matching conversation names.')}</dd>
  </dl>

  <h2 id="formatting">{l('Text formatting')}</h2>
  <p>{l('Convos supports some special way of formatting text:')}</p>
  <dl>
    <dt>{Object.keys(emojiAliases).sort().map(k => emojiAliases[k]).join(', ')}</dt>
    <dd>{l('Will be automatically converted into emojis.')}</dd>
    <dt>{l('> some text')}</dt>
    <dd>{l('A line starting with ">" will be converted into a quote.')}</dd>
    <dt>{l('*some text*, **some text**, ***some text***')}</dt>
    <dd>{@html lmd('Using "\*" around some text, will convert it into *italic*, **bold** or ***italic bold***.')}</dd>
    <dt>{l('`some fragment`')}</dt>
    <dd>{@html lmd('Using backticks around some text, will format it as a `code fragment`.')}</dd>
    <dt>https://...</dt>
    <dd>{l('URLs will be converted to links, and might be embedded in the chat.')}</dd>
  </dl>

  <h2 id="commands">{l('Available commands')}</h2>
  <dl>
    {#each commands as command}
      <dt>{command.example}</dt>
      <dd>{l(command.description)}</dd>
    {/each}
  </dl>

  <h2 id="resources">{l('Other resources')}</h2>
  <ul>
    <li><a href="https://convos.by" target="_blank">{l('Project homepage')}</a></li>
    <li><a href="https://github.com/Nordaaker/convos/issues" target="_blank">{l('Bug/issue tracker')}</a></li>
    <li><a href="https://github.com/Nordaaker/convos" target="_blank">{l('Source code')}</a></li>

    {#if settings.organization_name != 'Convos' && settings.organization_url != 'https://convos.by'}
      <li><a href="{settings.organization_url}" target="_blank">{settings.organization_name}</a></li>
    {/if}

    <li><a href="{settings.contact}" target="_blank">{l('Contact admin')}</a></li>
  </ul>
</main>
