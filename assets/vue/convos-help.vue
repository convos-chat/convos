<template>
  <div class="convos-help is-sidebar">
    <header><convos-menu :user="user"></convos-menu></header>
    <div class="content">
      <div class="row">
        <div class="col s12">
          <h5 v-if="!isTouchDevice">Shortcuts</h5>
          <p v-if="!isTouchDevice">These shortcuts are not yet implemented.</p>
          <dl v-if="!isTouchDevice">
            <dt>shift+enter</dt>
            <dd>Shift focus between chat input and dialog sidebar.</dd>
            <dt>tab (When writing a message)</dt>
            <dd>Will autocomplete a command, nick or channel name.</dd>
          </dl>
          <h5>Available commands</h5>
          <p>Commands are not yet supported.</p>
          <dl>
            <dt><a @click.prevent="insertIntoInput" href="#/help">/help</a></dt>
            <dd>Show this help dialog.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/close">/close [&lt;nick&gt;]</a></dt>
            <dd>Close conversation with nick, defaults to current active.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/join">/join &lt;#channel&gt;</a></dt>
            <dd>Join channel and open up a chat window.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/kick">/kick &lt;nick&gt;</a></dt>
            <dd>Kick a user from the current channel.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/me">/me &lt;message&gt;</a></dt>
            <dd>Send message as an action.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/msg">/msg &lt;nick&gt;</a></dt>
            <dd>Send a direct message to nick.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/nick">/nick &lt;nick&gt;</a></dt>
            <dd>Change your wanted nick.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/part">/part &lt;#channel&gt;</a></dt>
            <dd>Leave channel, and close window.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/query">/query &lt;nick&gt;</a></dt>
            <dd>Open up a new chat window with nick.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/reconnect">/reconnect</a></dt>
            <dd>Restart the current connection.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/say">/say &lt;message&gt;</a></dt>
            <dd>Used when you want to send a message starting with "/".</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/topic">/topic &lt;#channel&gt; [&lt;new topic&gt;]</a></dt>
            <dd>Show current topic, or set a new one.</dd>
            <dt><a @click.prevent="insertIntoInput" href="#/whois">/whois &lt;nick&gt;</a></dt>
            <dd>Show information about a user.</dd>
          </dl>
          <h5>Resources</h5>
          <ul>
            <li><a target="_blank" href="http://convos.by">Project homepage</a></li>
            <li><a target="_blank" href="https://github.com/Nordaaker/convos/issues">Bug/issue tracker</a></li>
            <li><a target="_blank" href="https://github.com/Nordaaker/convos">Source code</a></li>
          </ul>
          <p>
            It is also possible to chat with us in the "#convos" channel on
            <a target="_blank" href="http://freenode.net/">irc.freenode.net</a>.
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {props: ["user"]}
</script>
