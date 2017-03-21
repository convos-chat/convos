(function() {
  var makeGistHtml = function(gist) {
    var html ='';

    Object.$values(gist.files).forEach(function(g) {
      html += '<div class="link-embedder text-paste">';
      html += '<div class="paste-meta">';
      html += '<span>Hosted by</span> <a href="http://github.com">GitHub</a>';
      html += ' - <a href="' + g.raw_url + '">' + g.filename + '</a>'
      html += '</div>';
      html += '<pre>' + g.content.replace(/</g, "&lt;") +  '</pre>';
      html += '</div>';
    });

    return html;
  };

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
            else if (m = url.match(/https?:\/\/gist\.github\.com\/[^\/]+\/(\w+)/)) {
              $.get("https://api.github.com/gists/" + m[1], function(gist) {
                self.loadOffScreen(makeGistHtml(gist), id);
              });
            }
            else {
              $.get("/api/embed?url=" + encodeURIComponent(url), function(html, textStatus, xhr) {
                self.loadOffScreen(html, id);
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
        c["inactive-user"] = !msg.type.match(/^(notice|error)$/) && this.dialog.dialog_id && !this.dialog.participants[msg.from];
        c["same-user"] = prev.from == msg.from;

        return c;
      },
      loadOffScreen: function(html, id) {
        if (html.match(/^<a\s/)) return;
        var $html = $(html);
        var $a = $('#' + id);

        $html.filter("img").add($html.find("img")).addClass("embed materialboxed").on("error", function() { $(this).remove(); });
        $a.parent().append($html).find(".materialboxed").materialbox();
        $html.find("a").attr("target", "_blank");
        $html.find("pre").each(function() {
          var $container = $(this).closest(".link-embedder.text-paste");
          $container.find("a:first").attr("href", $a.attr("href"));
          $container.find(".paste-meta").click(function(e) {
            if (e.target.href) return;
            var $message = $container.closest(".convos-message");
            $container.toggleClass("expanded");
            $message.closest(".scroll-element").get(0).nextTickScrollTop = $message.get(0).offsetTop;
          });
          hljs.highlightBlock(this);
          var code = this.innerHTML.split(/\n\r?|\r/);
          $(this).replaceWith('<ol class="hljs"><li>' + code.join("</li><li>") + '</li></ol>');
        });
      },
      statusTooltip: function() {
        if (!this.dialog.dialog_id) return;
        return this.dialog.participants[this.msg.from] ? "" : "Not in this channel";
      }
    }
  };
})();
