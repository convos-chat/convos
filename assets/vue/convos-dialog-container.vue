<template>
  <div class="convos-dialog-container">
    <header>
      <h2 :data-hint="dialog.topic || 'No topic is set.'">{{dialog.name || 'Convos'}}</h2>
      <!-- a href="#search" data-hint="Search"><i class="material-icons">search</i></a -->
      <a v-if="dialog.connection" href="#info" @click.prevent="getInfo" data-hint="Get information"><i class="material-icons">info_outline</i></a>
      <a v-if="dialog.connection" href="#close" @click.prevent="closeDialog" data-hint="Close dialog"><i class="material-icons">close</i></a>
      <a v-if="!dialog.connection" href="#chat"><i class="material-icons">star_rate</i></a>
      <convos-menu :user="user" v-if="!sidebar"></convos-menu>
    </header>
    <main>
      <component
        :is="'convos-message-' + msg.type"
        :dialog="dialog"
        :msg="msg"
        :user="user"
        v-if="msg.type"
        v-for="msg in dialog.messages"></component>
    </main>
    <convos-input :dialog="dialog" :user="user"></convos-input>
  </div>
</template>
<script>
module.exports = {
  props: ["dialog", "sidebar", "user"],
  data:  function() {
    return {
      atBottom:          true,
      atBottomThreshold: !!("ontouchstart" in window) ? 60 : 40,
      scrollElement:     null
    };
  },
  methods: {
    closeDialog: function() {
      this.dialog.connection.send("/close " + this.dialog.name);
    },
    getInfo: function() {
      var self = this;
      // For debug purpose:
      // console.log(JSON.stringify(this.dialog.messages.map(function(m) {return [m.type, m.message]})));
      self.dialog.refreshParticipants(function(err) {
        if (!err) return this.emit("message", {type: "info"});
        return this.emit("message", {
          from:    this.connection.id,
          message: err ? err[0].message : "",
          type:    err ? "error" : "notice"
        });
      });
    },
    moveToBottomOnResize: function(e) {
      if (this._atBottomTid) return;
      var atBottom = this.atBottom;
      this._atBottomTid = setTimeout(function() {
        this.scrollToBottom(atBottom);
        this._atBottomTid = 0;
      }.bind(this),
        300
      );
    },
    onScroll: function() {
      var elem = this.scrollElement;
      this.atBottom = elem.scrollHeight < elem.offsetHeight + this.atBottomThreshold + elem.scrollTop;
      if (!elem.scrollTop) this.dialog.previousMessages();
    },
    scrollToBottom: function(force) {
      var elem = this.scrollElement;
      if (this.atBottom || force) {
        window.nextTick(function() {
          elem.scrollTop = elem.scrollHeight;
        });
      }
    }
  },
  ready: function() {
    this.scrollElement = $("main", this.$el)[0];
    this.scrollElement.addEventListener("scroll", this.onScroll);
    window.addEventListener("resize", this.moveToBottomOnResize);
    this.dialog.on("message", this.scrollToBottom);
    this.dialog.on("ready", this.scrollToBottom);
  },
  beforeDestroy: function() {
    window.removeEventListener("resize", this.moveToBottomOnResize);
    this.scrollElement.removeEventListener("scroll", this.onScroll);
  }
};
</script>
