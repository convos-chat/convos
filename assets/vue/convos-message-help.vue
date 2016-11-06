<template>
  <div class="convos-message can-be-closed">
    <a href="#close" @click.prevent="close()" class="secondary-content" v-tooltip.literal="Close"><i class="material-icons">close</i></a>
    <div class="message">{{msg.message}}</div>
      <h5>Resources</h5>
      <convos-resources></convos-resources>

      <h5>Commands</h5>
      <dl class="horizontal">
        <template v-for="cmd in commands">
          <dt><a @click.prevent="insertIntoInput" href="#/{{cmd.command}}">{{cmd.example || "/" + cmd.command}}</a></dt>
          <dd>{{cmd.description}}</dd>
        </template>
      </dl>

      <h5 v-if="!isTouchDevice">Shortcuts</h5>
      <dl class="horizontal" v-if="!isTouchDevice">
        <dt>shift+enter</dt>
        <dd>Shift focus between chat input and dialog sidebar.</dd>
        <dt>tab</dt>
        <dd>Will autocomplete a command, nick or channel name.</dd>
      </dl>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  mixins: [Convos.mixin.messageCanBeClosed],
  data: function() {
    return {commands: Convos.commands};
  }
};
</script>
