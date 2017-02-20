(function() {
  var THRESHOLD = 60;
  var TRACKING_TID;

  Convos.mixin.messages = {
    watch: {
      "dialog.active": function(active, prev) {
        if (!active) return;
        if (TRACKING_TID) clearTimeout(TRACKING_TID);
        this.reset = true;
        TRACKING_TID = setInterval(this.trackViewPort, 166);
      }
    },
    methods: {
      log: function(el, diff) {
        console.log(["[scroll:" + this.dialog.dialog_id + "]", this.atBottom, this.$refs.messages.length, el.scrollTop + "-" + this.scrollTop, el.scrollHeight + "-" + this.totalHeight, JSON.stringify(diff)].join(" "));
      },
      trackViewPort: function() {
        if (!this.$refs && this.$refs.messages) return; // setInterval() might go crazy
        var self = this;
        var messages = this.$refs.messages;
        var el = this.scrollEl;
        var scrollTop = el.scrollTop;
        var totalHeight = el.scrollHeight;
        var breakTop = scrollTop + (window.innerHeight || document.documentElement.clientHeight);
        var diff = {totalHeight: totalHeight - this.totalHeight, scrollTop: scrollTop - this.scrollTop};

        if (DEBUG.scroll && this.reset) this.log(el, diff);
        if (this.reset) return this.reset = !(el.scrollTop = totalHeight);
        if (!diff.totalHeight && !diff.scrollTop) return;
        if (!diff.totalHeight) this.atBottom = totalHeight - el.offsetHeight < scrollTop + THRESHOLD;
        if (DEBUG.scroll) this.log(el);
        if (this.atBottom) el.scrollTop = totalHeight;

        this.scrollTop = scrollTop;
        this.totalHeight = totalHeight;

        for (var i = 0; i < messages.length; i++) {
          var offsetTop = messages[i].$el.offsetTop;
          if (offsetTop > breakTop) break;
          if (offsetTop < scrollTop) continue;
          messages[i].$emit("visible");
        }

        if (diff.scrollTop && scrollTop < THRESHOLD) {
          this.dialog.load({historic: true}, function(err, body) {
            self.$nextTick(function() { el.scrollTop = scrollTop + el.scrollHeight - totalHeight });
          });
        }
      }
    },
    ready: function() {
      this.scrollEl = this.$el.querySelector(".scroll-element");
      this.scrollTop = 0;
      this.totalHeight = 0;
      this.atBottom = true;
    }
  };
})();
