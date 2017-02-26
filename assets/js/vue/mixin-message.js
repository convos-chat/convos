(function() {
  Convos.mixin.message = {
    props: ["dialog", "msg", "user"],
    data: function() {
      return {visible: false};
    },
    computed: {
      computedMessage: function() {
        var self = this;
        return self.msg.message.rich({
          after: function(url, id) {
            if (!self.settings.expandUrls || !self.visible) return;
            $.get("/api/embed?url=" + encodeURIComponent(url), function(html, textStatus, xhr) {
              self.loadOffScreen(html, id);
            });
          }
        });
      }
    },
    events: {
      visible: function() { this.visible = true; }
    },
    methods: {
      classNames: function() {
        var msg = this.msg;
        var c = {highlight: this.msg.highlight ? true : false};

        if (!msg.type.match(/^(notice|error)$/) && this.dialog.dialog_id && !this.dialog.participants[msg.from]) {
          c["inactive-user"] = true;
        }

        if (msg.message && msg.from == msg.prev.from) {
          c["same-user"] = true;
        }
        else {
          c["changed-user"] = true;
        }

        return c;
      },
      loadOffScreen: function(html, id) {
        if (html.match(/^<a\s/)) return;

        // TODO: Add support for showing paste inline
        if (html.match(/class=".*(text-paste|text-gist-github)/)) return;

        var self = this;
        var $html = $(html);
        var $a = $('#' + id);

        $html.filter("img").add($html.find("img")).addClass("embed materialboxed").on("error", function() { $(this).remove(); });
        $a.parent().append($html).find(".materialboxed").materialbox();
      },
      statusTooltip: function() {
        return this.dialog.participants[this.msg.from] ? "" : "Not in this channel";
      }
    }
  };
})();
