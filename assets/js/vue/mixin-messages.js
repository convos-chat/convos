(function() {
  var offset = 60;

  Convos.mixin.messages = {
    data: function() {
      return {atBottom: true, offsetElement: null, scrollElement: null};
    },
    watch: {
      'settings.screenHeight': function(v, o) {
        this.keepScrollPos({});
      }
    },
    methods: {
      onScroll: function() {
        if (this._scrollTid) return;
        this._scrollTid = setTimeout(function() {
          var self = this;
          var el = this.scrollElement;

          this._scrollTid = null;
          this.atBottom = el.scrollHeight < el.offsetHeight + offset + el.scrollTop;
          this.trackVisibleMessage();

          console.log('atBottom', this.atBottom, el.scrollHeight, el.offsetHeight, offset, el.scrollTop);

          if (el.scrollTop < offset) {
            this.dialog.historicMessages({}, function(err, body) { });
          }
        }.bind(this), 100);
      },
      keepScrollPos: function() {
        var self = this;
        var el = this.scrollElement;

        window.nextTick(function() {
          if (self.atBottom) return el.scrollTop = el.scrollHeight;
          if (self.offsetElement) return el.scrollTop = self.offsetElement.offsetTop - 10;
        });
      },
      trackVisibleMessage: function() {
        var messages = this.scrollElement.querySelectorAll(".convos-message");
        var st = this.scrollElement.scrollTop;
        var n = 0;
        while (++n < messages.length) {
          if (messages[n].offsetTop < st) continue;
          this.offsetElement = messages[n];
          break;
        }
      }
    },
    ready: function() {
      this.scrollElement = this.$el.querySelector(".scroll-element");
      this.scrollElement.addEventListener("scroll", this.onScroll);
      this.dialog.on("message", this.trackVisibleMessage);
      this.dialog.on("message", this.keepScrollPos);
    },
    beforeDestroy: function() {
      this.scrollElement.removeEventListener("scroll", this.onScroll);
    }
  };
})();
