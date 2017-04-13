(function() {
  Convos.mixin.message = {
    props: ["dialog", "msg", "user"],
    data: function() {
      return {visible: false};
    },
    computed: {
      computedMessage: function() {
        var m, self = this;
        return self.msg.message.rich({
          after: function(url, id) {
            if (!self.settings.expandUrls || !self.visible) {
              return;
            }
            else {
              $.get("/api/embed.json?url=" + encodeURIComponent(url), function(oembed, textStatus, xhr) {
                self.loadOffScreen(oembed, id);
              });
            }
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
        var i = this.dialog.messages.indexOf(msg);
        var prev = i > 0 ? this.dialog.messages[i - 1] : {};
        var c = {};

        c["highlight"] = this.msg.highlight;
        c["inactive-user"] = !msg.type.match(/^(notice|error)$/) && this.dialog.dialog_id && !this.dialog.participant(msg.from).online;
        c["same-user"] = prev.from == msg.from;

        return c;
      },
      loadOffScreen: function(oembed, id) {
        if (oembed.type == 'link') return;
        var $html = $(oembed.html);
        var $a = $('#' + id);

        $html.filter("img").add($html.find("img")).addClass("embed materialboxed").on("error", function() { $(this).remove(); });
        $a.parent().append($html).find(".materialboxed").materialbox();
        $html.find("a").attr("target", "_blank");
        $html.find("pre").each(function() {
          var $container = $(this).closest(".le-paste");
          $container.find(".le-meta").click(function(e) {
            if (e.target.href) return;
            var $message = $container.closest(".convos-message");
            $container.toggleClass("expanded");
            $message.closest(".scroll-element").get(0).nextTickScrollTop = $message.get(0).offsetTop;
          });
          hljs.highlightBlock(this);
          var code = this.innerHTML.split(/\n\r?|\r/);
          $(this).replaceWith('<ol class="hljs"><li>' + code.join("</li><li>") + '</li></ol>');
        });
        if (oembed.provider_name == 'Twitter') twttr.widgets.load();
        if (oembed.provider_name == 'Instagram') instgrm.Embeds.process();
      },
      statusTooltip: function() {
        if (!this.dialog.dialog_id) return;
        return this.dialog.participant(this.msg.from).online ? "" : "Not in this channel";
      }
    }
  };
})();
