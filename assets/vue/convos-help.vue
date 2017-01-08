<template>
  <div class="convos-help">
    <div class="row">
      <div class="col s12">
        <h4>Help</h4>
        <p>
          Got any questions? Come and talk to us in the "#convos" channel on
          <a target="_blank" href="http://freenode.net/">irc.freenode.net</a>.
          More information can also be found on <a href="http://convos.by">http://convos.by</a>.
        </p>
      </div>
    </div>
    <div class="row">
      <div class="col s12">
        <h5 v-if="!isTouchDevice">Shortcuts</h5>
        <dl v-if="!isTouchDevice">
          <dt>shift+enter</dt>
          <dd>Shift focus between chat input and dialog sidebar.</dd>
          <dt>tab (When writing a message)</dt>
          <dd>Will autocomplete a command, nick or channel name.</dd>
        </dl>
        <h5>Available commands</h5>
        <dl>
          <template v-for="cmd in commands">
            <dt><a @click.prevent="insertIntoInput" href="#/{{cmd.command}}">{{cmd.example || "/" + cmd.command}}</a></dt>
            <dd>{{cmd.description}}</dd>
          </template>
        </dl>
        <h5>Resources</h5>
        <convos-resources></convos-resources>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {commands: Convos.commands};
  }
};
</script>
