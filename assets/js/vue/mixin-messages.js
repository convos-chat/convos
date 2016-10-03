(function() {
  Convos.mixin.messages = {
    data: function() {
      return {
        atBottom: true,
        scrolling: 0,
        scrollElement: null,
        scrollThreshold: 60
      };
    },
    watch: {
      'settings.screenHeight': function(v, o) {
        if (!this.scrolling++) return;
        var atBottom = this.atBottom;
        setTimeout(function() {
          this.scrolling = 0;
          this.scrollToBottom({gotoBottom: atBottom});
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
            window.nextTick(function() { elem.scrollTop = elem.scrollHeight - scrollHeight - 100; });
          });
        }
      },
      scrollToBottom: function(args) {
        if (!this.scrolling++ && (this.atBottom || args.gotoBottom)) {
          window.nextTick(function() {
              this.scrolling = 0;
              this.scrollElement.scrollTop = this.scrollElement.scrollHeight;
          }.bind(this));
        }
      }
    },
    ready: function() {
      this.scrollElement = this.$el.querySelector(".scroll-element");
      this.scrollElement.addEventListener("scroll", this.onScroll);
      this.dialog.on("message", this.scrollToBottom);
    },
    beforeDestroy: function() {
      this.scrollElement.removeEventListener("scroll", this.onScroll);
    }
  };
})();
