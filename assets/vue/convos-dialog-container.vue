<template>
  <div class="convos-dialog-container">
    <header>
      <h2 :data-hint="dialog.topic || 'No topic is set.'">{{dialog.name || 'Convos'}}</h2>
      <convos-menu :toggle="true" :user="user">
        <!-- a href="#search" data-hint="Search"><i class="material-icons">search</i></a -->
        <a href="#info" @click.prevent="getInfo" data-hint="Get information"><i class="material-icons">info_outline</i></a>
        <a href="#close" @click.prevent="closeDialog" data-hint="Close dialog"><i class="material-icons">close</i></a>
      </convos-menu>
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
      atBottom:          true,
      atBottomThreshold: !!("ontouchstart" in window) ? 60 : 40,
      scrollElement:     null
    };
  },
  methods: {
    closeDialog: function() {
      this.dialog.connection().send("/close " + this.dialog.name);
    },
    getInfo: function() {
      var self = this;
      self.dialog.refreshParticipants(function(err) {
        if (!err) return this.addMessage({type: "info"});
        this.addMessage({message: err[0].message, type: "error"});
      });
    },
    moveToBottomOnResize: function(e) {
      if (this._atBottomTid) return;
      var atBottom = this.atBottom;
      this._atBottomTid = setTimeout(function() {
        this.scrollToBottom({gotoBottom: atBottom});
        this._atBottomTid = 0;
      }.bind(this),
        300
      );
    },
    onScroll: function() {
      var elem = this.scrollElement;
      this.atBottom = elem.scrollHeight < elem.offsetHeight + this.atBottomThreshold + elem.scrollTop;
      if (!elem.scrollTop) this.dialog.historicMessages();
    },
    scrollToBottom: function(args) {
      var elem = this.scrollElement;
      if (this.atBottom || args.gotoBottom) {
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
    this.dialog.on("initialized", this.scrollToBottom);
    this.dialog.on("message", this.scrollToBottom);
  },
  beforeDestroy: function() {
    window.removeEventListener("resize", this.moveToBottomOnResize);
    this.scrollElement.removeEventListener("scroll", this.onScroll);
  }
};
</script>
