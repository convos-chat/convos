<template>
  <div class="convos-message notice">
    <a href="#chat" class="title">{{msg.from}}</a>
    <div class="message">
      <abbr v-tooltip.literal="{{msg.name}}">{{msg.nick}}</abbr>
      <template v-if="msg.idle_for">has been idle for {{msg.idle_for}} seconds in</template>
      <template v-else="msg.idle_for">is active in</template>
      <template v-for="name in channels">
        {{!$index ? '' : $index + 1 == channels.length ? "and" : ", "}}
        <a href="#join:{{name}}" @click.prevent="join(name)">{{name}}</a>
      </template>.
    </div>
    <span class="secondary-content ts" v-tooltip="msg.ts.toLocaleString()">{{msg.ts | timestring}}</span>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "msg", "user"],
  data: function() {
    return {channels: Object.keys(this.msg.channels)};
  },
  methods: {
    join: function(name) {
      var connection = this.dialog.connection();
      var dialog = connection.getDialog(name);
      if (dialog) return this.settings.main = dialog.href();
      connection.send('/join ' + name, this.dialog);
    }
  }
};
</script>
