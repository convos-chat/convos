<template>
  <div class="convos-dialog-container">
    <header>
      <convos-toggle-main-menu :user="user"></convos-toggle-main-menu>
      <h2 v-tooltip="dialog.topic || 'No topic is set.'">{{user.ws.is('open') ? dialog.name || 'Convos' : 'No internet connection?'}}</h2>
      <convos-header-links :toggle="true" :user="user"></convos-header-links>
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
  props: ["dialog", "user"],
  data:  function() {
    return {
      atBottom: true,
      scrollElement: null,
      scrollThreshold: !!("ontouchstart" in window) ? 60 : 40
    };
  },
  watch: {
    'settings.windowHeight': function(v, o) {
      if (this._atBottomTid) return;
      var atBottom = this.atBottom;
      this._atBottomTid = setTimeout(function() {
        this.scrollToBottom({gotoBottom: atBottom});
        this._atBottomTid = 0;
      }.bind(this), 300);
    }
  },
  methods: {
    onScroll: function() {
      var self = this;
      var elem = this.scrollElement;
      this.atBottom = elem.scrollHeight < elem.offsetHeight + this.scrollThreshold + elem.scrollTop;
      if (elem.scrollTop < this.scrollThreshold) {
        this.dialog.historicMessages({}, function(err, cb) {
          var scrollHeight = elem.scrollHeight;
          if (cb) cb();
          if (self.atBottom) return self.scrollToBottom({});
          window.nextTick(function() { elem.scrollTop = elem.scrollHeight - scrollHeight - 100; });
        });
      }
    },
    scrollToBottom: function(args) {
      var elem = this.scrollElement;
      if (this.atBottom || args.gotoBottom) {
        window.nextTick(function() { elem.scrollTop = elem.scrollHeight; });
      }
    }
  },
  ready: function() {
    this.scrollElement = $("main", this.$el)[0];
    this.scrollElement.addEventListener("scroll", this.onScroll);
    this.dialog.on("active", function() { this.scrollToBottom({gotoBottom: true}); }.bind(this));
    this.dialog.on("message", this.scrollToBottom);
  },
  beforeDestroy: function() {
    this.scrollElement.removeEventListener("scroll", this.onScroll);
  }
};
</script>
