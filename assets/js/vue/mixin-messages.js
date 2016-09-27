(function() {
  Convos.mixin.messages = {
    data: function() {
      return {
        atBottom: true,
        scrollElement: null,
        scrollThreshold: 60
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
      this.scrollElement = $(".scroll-element", this.$el)[0];
      this.scrollElement.addEventListener("scroll", this.onScroll);
      this.dialog.on("active", function() { this.scrollToBottom({gotoBottom: true}); }.bind(this));
      this.dialog.on("message", this.scrollToBottom);
      this.scrollToBottom();
    },
    beforeDestroy: function() {
      this.scrollElement.removeEventListener("scroll", this.onScroll);
    }
  };
})();
