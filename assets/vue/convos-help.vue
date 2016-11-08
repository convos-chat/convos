<template>
  <div class="convos-help is-sidebar">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <convos-header-links :user="user"></convos-header-links>
    </header>
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
