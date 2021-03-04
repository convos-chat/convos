<script>
import ChatHeader from '../components/ChatHeader.svelte';
import Link from '../components/Link.svelte';
import {commands} from '../js/commands';
import {emojiAliases} from '../js/md';
import {l, lmd} from '../store/I18N';
import {settings} from '../js/util';

export const title = 'Help';

const changelogUrl = 'https://github.com/convos-chat/convos/blob/v' + settings('version') + '/Changes#L3';
</script>

<ChatHeader>
  <h1>{$l('Help')} <small><a href="{changelogUrl}" target="_blank">v{settings('version')}</a></small></h1>
</ChatHeader>

<main class="main">
  <p>
    {@html $lmd('Got any questions? Come and talk to us in the "#convos" channel on https://freenode.net.')}
    {@html $lmd('More information can also be found on https://convos.chat.')}
  </p>

  <h2 id="quick-search">{$l('Quick search')}</h2>
  <p>{$l('Pressing `shift+enter` will shift focus between chat input and search in sidebar.')}</p>
  <dl>
    <dt>+</dt>
    <dd>{$l('Filter conversations with unread messages.')}</dd>
    <dt>+@</dt>
    <dd>{$l('Filter private conversations with unread messages.')}</dd>
    <dt>+#</dt>
    <dd>{$l('Filter channels with unread messages.')}</dd>
    <dt>{$l('Any other combination')}</dt>
    <dd>{$l('Filter channels, private conversations or search for a string.')}</dd>
  </dl>

  <h2 id="autocomplete">{$l('Autocomplete')}</h2>
  <p>{$l('The following rules apply when typing a message:')}</p>
  <dl>
    <dt>@nick</dt><dd>{$l('"@" followed by a character will show matching nicks in the current conversation.')}</dd>
    <dt>:emoji_name</dt><dd>{$l('":" followed by a character will show matching emojis.')}</dd>
    <dt>/command</dt><dd>{$l('"/" will show the available commands.')}</dd>
    <dt>#conversation</dt><dd>{$l('"#" will show the matching conversation names.')}</dd>
  </dl>

  <h2 id="formatting">{$l('Text formatting')}</h2>
  <p>{$l('Convos supports some special way of formatting text:')}</p>
  <dl>
    <dt>{Object.keys(emojiAliases).sort().map(k => emojiAliases[k]).join(', ')}</dt>
    <dd>{$l('Will be automatically converted into emojis.')}</dd>
    <dt>{$l('> some text')}</dt>
    <dd>{$l('A line starting with ">" will be converted into a quote.')}</dd>
    <dt>{$l('*some text*, **some text**, ***some text***')}</dt>
    <dd>{@html $lmd('Using "\*" around some text, will convert it into *italic*, **bold** or ***italic bold***.')}</dd>
    <dt>{$l('`some fragment`')}</dt>
    <dd>{@html $lmd('Using backticks around some text, will format it as a `code fragment`.')}</dd>
    <dt>https://...</dt>
    <dd>{$l('URLs will be converted to links, and might be embedded in the chat.')}</dd>
  </dl>

  <h2 id="commands">{$l('Available commands')}</h2>
  <p>{@html $lmd('Any message starting with a-z is prefixed with "`/quote`", when sending from a connection conversation.')}</p>
  <dl>
    {#each commands as command}
      <dt>{command.example}</dt>
      <dd>{$l(command.description)}</dd>
    {/each}
  </dl>

  <h2 id="resources">{$l('Other resources')}</h2>
  <ul>
    <li><a href="{changelogUrl}" target="_blank">{$l('Changelog for v%1', settings('version'))}</a></li>
    <li><a href="https://convos.chat" target="_blank">{$l('Project homepage')}</a></li>
    <li><a href="https://github.com/convos-chat/convos/issues" target="_blank">{$l('Bug/issue tracker')}</a></li>
    <li><a href="https://github.com/convos-chat/convos" target="_blank">{$l('Source code')}</a></li>

    {#if settings('organization_name') != 'Convos' && settings('organization_url') != 'https://convos.chat'}
      <li><a href="{settings('organization_url')}" target="_blank">{settings('organization_name')}</a></li>
    {/if}

    <li><a href="{settings('contact')}" target="_blank">{$l('Contact admin')}</a></li>
  </ul>

  <h2 id="fallback">{$l('Demo error pages')}</h2>
  <ul>
    <li><Link href="/err/loading">Loading</Link></li>
    <li><Link href="/err/not_found">Not found</Link></li>
    <li><Link href="/err/unknown">Unknown</Link></li>
  </ul>
</main>
