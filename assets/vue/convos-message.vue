<template>
  <div class="convos-message">
    <span v-if="msg.type == 'action'">✧</span>
    <a href="#insert:{{msg.from}}" class="title" @click.prevent="insertIntoInput(msg.from)">{{msg.from}}</a>
    <div class="message" v-if="msg.type != 'error'"><span>{{{message() | markdown}}}</span></div>
    <div class="error" v-if="msg.type == 'error'">{{msg.message}}</div>
    <span class="secondary-content ts" :data-hint="msg.ts.toLocaleString()" v-if="msg.ts">{{msg.ts | timestring}}</span>
  </div>
</template>
<script>
module.exports = {
  props:   ["dialog", "msg", "user"],
  methods: {
    insertIntoInput: function(str) {
      this.dialog.emit("insertIntoInput", str);
    },
    message: function() {
      var self = this;
      return this.msg.message.xmlEscape().autoLink({
        target: "_blank",
        after:  function(url, id) {
          $.get("/api/embed?url=" + encodeURIComponent(url), function(html, textStatus, xhr) {
            self.$dispatch("loadOffScreen", html, id);
          });
          return null;
        }
      });
    }
  },
  ready: function() {
    var self = this;
    var msg  = this.msg;
    var prev = msg.prev;

    $(this.$el).addClass(msg.classNames.join(" "));
    $(this.$el).addClass(
      msg.message && msg.from == prev.from && msg.ts.epoch() - 300 < prev.ts.epoch()
        ? "same-user" : "changed-user");
  }
};
</script>
