<script>
import {l, lmd} from '../js/i18n';
import SidebarChat from '../components/SidebarChat.svelte';

const version = '1.0.0'; // TODO: Extract version from package.json
</script>

<SidebarChat/>

<main class="main">
  <header class="header"><h1>{l('Help')}</h1><small>v{version}</small></header>

  <p>
    {@html lmd('Got any questions? Come and talk to us in the "#convos" channel on http://freenode.net.')}
    {@html lmd('More information can also be found on http://convos.by.')}
  </p>

  <h2>{l('Shortcuts')}</h2>
  <dl>
    <dt>shift+enter</dt>
    <dd>Shift focus between chat input and dialog sidebar.</dd>
    <dt>tab (When writing a message)</dt>
    <dd>Will autocomplete a command, nick or channel name.</dd>
  </dl>

  <h2>{l('Available commands')}</h2>
  <dl>
    <dt><a href="#/me">/me &lt;msg&gt;</a></dt>
    <dd>Send message as an action.</dd><dt><a href="#/say">/say &lt;msg&gt;</a></dt>
    <dd>Used when you want to send a message starting with "/".</dd><dt><a href="#/topic">/topic or /topic &lt;new topic&gt;</a></dt>
    <dd>Show current topic, or set a new one.</dd><dt><a href="#/whois">/whois &lt;nick&gt;</a></dt>
    <dd>Show information about a user.</dd><dt><a href="#/query">/query &lt;nick&gt;</a></dt>
    <dd>Open up a new chat window with nick.</dd><dt><a href="#/msg">/msg &lt;nick&gt; &lt;msg&gt;</a></dt>
    <dd>Send a direct message to nick.</dd><dt><a href="#/names">/names</a></dt>
    <dd>Show participants in the channel.</dd><dt><a href="#/join">/join &lt;#channel&gt;</a></dt>
    <dd>Join channel and open up a chat window.</dd><dt><a href="#/nick">/nick &lt;nick&gt;</a></dt>
    <dd>Change your wanted nick.</dd><dt><a href="#/part">/part</a></dt>
    <dd>Leave channel, and close window.</dd><dt><a href="#/close">/close &lt;nick&gt;</a></dt>
    <dd>Close conversation with nick, defaults to current active.</dd><dt><a href="#/kick">/kick &lt;nick&gt;</a></dt>
    <dd>Kick a user from the current channel.</dd><dt><a href="#/mode">/mode</a></dt>
    <dd>Change mode of yourself or a user</dd><dt><a href="#/reconnect">/reconnect</a></dt>
    <dd>Restart the current connection.</dd><dt><a href="#/cs">/cs &lt;msg&gt;</a></dt>
    <dd>Short for "/msg chanserv ...".</dd><dt><a href="#/ns">/ns &lt;msg&gt;</a></dt>
    <dd>Short for "/msg nickserv ...".</dd><dt><a href="#/hs">/hs &lt;msg&gt;</a></dt>
    <dd>Short for "/msg hostserv ...".</dd><dt><a href="#/bs">/bs &lt;msg&gt;</a></dt>
    <dd>Short for "/msg botserv ...".</dd>
  </dl>

  <h2>{l('Resources')}</h2>
  <ul>
    <li><a href="http://convos.by" target="_blank">{l('Project homepage')}</a></li>
    <li><a href="https://github.com/Nordaaker/convos/issues" target="_blank">{l('Bug/issue tracker')}</a></li>
    <li><a href="https://github.com/Nordaaker/convos" target="_blank">{l('Source code')}</a></li>
  </ul>
</main>
