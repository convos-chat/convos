(function() {
  var THRESHOLD = 60;

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
        if (!this._atBottomTid) this._atBottomTid = setInterval(this.keepAtBottom, 200);
      },
      deactivate: function() {
        this.dialog.setLastRead();
        if (this._atBottomTid) clearTimeout(this._atBottomTid);
        delete this._atBottomTid;
      },
      keepAtBottom: function() {
        if (!this.atBottom) return;
        var el = this.scrollElement;
        if (el.scrollTop > el.scrollHeight - el.offsetHeight - 10) return;
        this.scrollTid = "lock"; // need to prevent the next detectVisibleMessages() call triggered by scrollTop below
        el.scrollTop = el.scrollHeight;
      },
      detectVisibleMessages: function() {
        if (this.scrollTid == "lock") return this.scrollTid = 0;
        if (this.scrollTid) return;

        this.scrollTid = setTimeout(function() {
          var children = this.$children.filter(function(c) { return c.loadOffScreen; });
          var el =  this.scrollElement;
          var scrollTop = el.scrollTop;
          var innerHeight = window.innerHeight || document.documentElement.clientHeight;
          var found = [];

          this.scrollTid = 0;
          this.atBottom = el.scrollTop > el.scrollHeight - el.offsetHeight - THRESHOLD;

          for (var i = 0; i < children.length; i++) {
            var offsetTop = children[i].$el.offsetTop;
            if (offsetTop > scrollTop + innerHeight) break;
            if (offsetTop < scrollTop) continue;
            children[i].$emit("visible");
            found.push(children[i]);
          }

          if (scrollTop < THRESHOLD && innerHeight < el.scrollHeight) {
            this.dialog.load({historic: true}, function(err, body) {
              window.nextTick(function() { el.scrollTop = found[0].$el.offsetTop; });
            });
          }
        }.bind(this), 200);
      }
    },
    ready: function() {
      var self = this;
      // Need to use $nextTick, since the "message" event is triggered before the element is rendered on the page
      this.dialog.on("message", function() { self.$nextTick(self.detectVisibleMessages); });
      this.scrollElement = this.$el.querySelector(".scroll-element");
      this.scrollElement.addEventListener("scroll", this.detectVisibleMessages);
    },
    beforeDestroy: function() {
      this.scrollElement.removeEventListener("scroll", this.detectVisibleMessages);
    }
  };
})();
