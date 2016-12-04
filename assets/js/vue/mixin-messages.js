(function() {
  var offset = 60;

  Convos.mixin.messages = {
    data: function() {
      return {atBottom: true, scrollElement: null};
    },
    watch: {
      "dialog.active": function(v, o) {
        if (v === false && o === true) this.deactivate();
        if (v === true) this.activate();
      }
    },
    methods: {
      activate: function() {
        this.dialog.activate();
        if (this._atBottomTid) return;
        this._atBottomTid = setInterval(this.keepAtBottom, 200);
      },
      deactivate: function() {
        this.dialog.setLastRead();
        if (this._atBottomTid) clearTimeout(this._atBottomTid);
        delete this._atBottomTid;
      },
      findVisibleMessage: function() {
        var messages = this.scrollElement.querySelectorAll(".convos-message");
        var st = this.scrollElement.scrollTop;
        var n = 0;
        while (++n < messages.length) {
          if (messages[n].offsetTop >= st) return messages[n];
        }
        return null;
      },
      keepAtBottom: function() {
        var el = this.scrollElement;
        if (!this.atBottom) return;
        if (el.scrollTop > el.scrollHeight - el.offsetHeight - 10) return;
        el.scrollTop = el.scrollHeight;
      },
      onScroll: function() {
        if (this._scrollTid) return;
        this._scrollTid = setTimeout(function() {
          var self = this;
          var msgEl, el = this.scrollElement;

          this._scrollTid = null;
          this.atBottom = el.scrollTop > el.scrollHeight - el.offsetHeight - offset;

          if (el.scrollTop < offset) {
            var msgEl = this.findVisibleMessage();
            this.dialog.historicMessages({}, function(err, body) {
              if (msgEl) window.nextTick(function() { el.scrollTop = msgEl.offsetTop; });
            });
          }
        }.bind(this), 100);
      }
    },
    ready: function() {
      this.scrollElement = this.$el.querySelector(".scroll-element");
      this.scrollElement.addEventListener("scroll", this.onScroll);
      this.dialog.on("message", this.keepAtBottom);
    },
    beforeDestroy: function() {
      this.scrollElement.removeEventListener("scroll", this.onScroll);
    }
  };
})();
