(function() {
  var THRESHOLD = 60;

  Convos.mixin.messages = {
    watch: {
      "dialog.active": function(v, o) {
        if (v === false && this._trackTid) clearTimeout(this._trackTid);
        if (v === true) this._trackTid = setInterval(this.trackViewPort, 200);
        this.atBottom = true;
      }
    },
    methods: {
      trackViewPort: function() {
        var self = this;
        var messages = this.$refs.messages || [];
        var el = this.scrollEl;
        var scrollHeight = el.scrollHeight;
        var scrollTop = el.scrollTop;
        var breakTop = scrollTop + (window.innerHeight || document.documentElement.clientHeight);
        var diff = {scrollHeight: scrollHeight - this.scrollHeight, scrollTop: scrollTop - this.scrollTop};

        if (!diff.scrollHeight && !diff.scrollTop) return;
        if (!diff.scrollHeight) this.atBottom = scrollHeight - el.offsetHeight < scrollTop + THRESHOLD;
        if (DEBUG.scroll) console.log(["[scroll:" + this.dialog.dialog_id + "]", this.atBottom, messages.length, scrollTop + "-" + this.scrollTop, scrollHeight + "-" + this.scrollHeight].join(" "));
        if (this.atBottom) el.scrollTop = scrollHeight;

        this.scrollHeight = scrollHeight;
        this.scrollTop = scrollTop;

        for (var i = 0; i < messages.length; i++) {
          var offsetTop = messages[i].$el.offsetTop;
          if (offsetTop > breakTop) break;
          if (offsetTop < scrollTop) continue;
          messages[i].$emit("visible");
        }

        if (diff.scrollTop && scrollTop < THRESHOLD) {
          this.dialog.load({historic: true}, function(err, body) {
            self.$nextTick(function() { el.scrollTop = scrollTop + el.scrollHeight - scrollHeight });
          });
        }
      }
    },
    ready: function() {
      this.atBottom = true;
      this.scrollHeight = 0;
      this.scrollTop = 0;
      this.scrollEl = this.$el.querySelector(".scroll-element");
      this.dialog.on("message", function() { this.$nextTick(this.trackViewPort); }.bind(this));
    },
    beforeDestroy: function() {
      if (this._trackTid) clearTimeout(this._trackTid);
    }
  };
})();
