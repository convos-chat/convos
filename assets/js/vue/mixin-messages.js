(function() {
  var DEBUG_VISIBLE_MESSAGES = location.href.match(/debug=detectVisibleMessages/);
  var THRESHOLD = 60;

  Convos.mixin.messages = {
    data: function() {
      return {atBottom: true, scrollEl: null, scrollTid: 0};
    },
    watch: {
      "dialog.active": function(v, o) {
        if (v === false && o === true && this._atBottomTid) clearTimeout(this._atBottomTid);
        if (v === true && !this._atBottomTid) this._atBottomTid = setInterval(this.keepAtBottom, 200);
      }
    },
    methods: {
      detectVisibleMessages: function(e) {
        var self = this;
        var el = this.scrollEl;
        var children = this.$children.filter(function(c) { return c.loadOffScreen; });
        var scrollTop = el.scrollTop;
        var innerHeight = window.innerHeight || document.documentElement.clientHeight;
        var visible = [];

        this.scrollTid = 0;
        this.atBottom = scrollTop > el.scrollHeight - el.offsetHeight - THRESHOLD;

        for (var i = 0; i < children.length; i++) {
          var offsetTop = children[i].$el.offsetTop;
          if (offsetTop > scrollTop + innerHeight) break;
          if (offsetTop < scrollTop) continue;
          children[i].$emit("visible");
          visible.push(children[i]);
        }

        if (scrollTop < THRESHOLD && innerHeight < el.scrollHeight) {
          this.dialog.load({historic: true}, function(err, body) {
            if (!visible[0]) return;
            self.scrollTid = "lock";
            self.$nextTick(function() { this.scrollEl.scrollTop = visible[0].$el.offsetTop; });
          });
        }
      },
      onChange: function(e) {
        if (DEBUG_VISIBLE_MESSAGES) console.log("[" + this.dialog.dialog_id + "] atBottom:", this.atBottom, "scrollTid:", (this.scrollTid > 0 ? "active" : this.scrollTid));
        if (!e) this.keepAtBottom();
        if (this.scrollTid == "lock") return this.scrollTid = 0;
        if (!this.scrollTid) this.scrollTid = setTimeout(this.detectVisibleMessages, 300);
      },
      keepAtBottom: function() {
        if (this.atBottom) this.scrollEl.scrollTop = this.scrollEl.scrollHeight;
      }
    },
    ready: function() {
      var self = this;
      // Need to use $nextTick, since the "message" event is triggered before the element is rendered on the page
      this.dialog.on("message", function() { this.$nextTick(this.onChange); }.bind(this));
      this.scrollEl = this.$el.querySelector(".scroll-element");
      this.scrollEl.addEventListener("scroll", this.onChange);
    },
    beforeDestroy: function() {
      this.scrollEl.removeEventListener("scroll", this.onChange);
    }
  };
})();
