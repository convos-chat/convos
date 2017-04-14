(function() {
  var text2emoji = {
    "&lt;3": ":heart:",
    ":(": ":disappointed:",
    ":)": ":slight_smile:",
    ":/": ":confused:",
    ":D": ":smiley:",
    ":P": ":stuck_out_tongue:",
    ";)": ":wink:",
    ";D": ":wink:",
    "<3": ":heart:"
  };

  var entity = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
    " ": "&nbsp;"
  };

  var text2emojiRe = Object.keys(text2emoji).map(function(s) { return s.replace(/([\(\)])/g, "\\$1"); }).join("|");
  var codeToHtmlRe = new RegExp("(\\\\?)`([^`]+)`", "g");
  var mdToHtmlRe = new RegExp("(^|\\s)(\\\\?)(\\*+|_+)(\\w[^<]*?)\\3", "g");

  text2emojiRe = new RegExp("(^|\\s)(" + text2emojiRe + ")(?=\\s|$)", "i");

  // rich({emoji: true, escape: true, links: true});
  String.prototype.rich = function(args) {
    if (!args) args = {};
    var str = this;

    // & => &amp;
    str = str.replace(/[&<>"']/g, function(m) {
      return entity[m];
    });

    // double whitespace
    str = str.replace(/[ ]{2}/g, function(m) {
      return entity[" "] + " ";
    });

    // *foo*     or _foo_     => <em>foo</em>
    // **foo**   or __foo__   => <strong>foo</strong>
    // ***foo*** or ___foo___ => <em><strong>foo</strong></em>
    // \*foo*    or \_foo_    => *foo* or _foo_
    if (args.markdown !== false) {
      str = str.replace(mdToHtmlRe, function(all, b, esc, md, text) {
        if (md.match(/^_/) && text.match(/^[A-Z]+$/)) return all; // Avoid __DATA__
        switch (md.length) {
          case 1:
            return esc ? all.replace(/^\\/, "") : b + "<em>" + text + "</em>";
          case 2:
            return esc ? all.replace(/^\\/, "") : b + "<strong>" + text + "</strong>";
          case 3:
            return esc ? all.replace(/^\\/, "") : b + "<em><strong>" + text + "</strong></em>";
          default:
            return all;
        }
      });

      // `some string` => <code>some string</code>
      str = str.replace(codeToHtmlRe, function(all, esc, text) {
        return esc ? all.replace(/^\\/, "") : "<code>" + text + "</code>";
      });
    }

    str = emojione.toImage(str.replace(text2emojiRe, function(m, pre, emoji) {
      return pre + (text2emoji[emoji] || emoji);
    }));

    if (args.autoLink !== false) {
      str = str.autoLink({after: args.after, target: args.target || "_blank"});
    }

    return str;
  };

  var numbers = {
    0:  "zero",
    1:  "one",
    2:  "two",
    3:  "three",
    4:  "four",
    5:  "five",
    6:  "six",
    7:  "seven",
    8:  "eight",
    9:  "nine",
    10: "ten"
  };
  String.prototype.numberAsString = function() {
    return numbers[this] || "" + this;
  };

  var urlRe = new RegExp("^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?");
  String.prototype.parseUrl = function() {
    var m = this.match(urlRe);
    if (!m) return {};
    m = m.map(function(v) { return typeof v == "undefined" ? "" : v; });
    var s = {
      input:     this,
      scheme:    m[2],
      authority: m[4],
      path:      m[5],
      fragment:  m[9],
      query:     {}
    };
    var p = m[4].split("@", 2);

    s.hostPort    = p[1] || p[0];
    s.userinfo    = p.length == 2 ? p[0].split(":", 2) : [];
    s.queryString = m[7];
    p             = m[7] ? m[7].split("&") : [];

    p.forEach(function(i) {
      var kv = i.split("=", 2);
      s.query[kv[0]] = kv[1];
    });

    return s;
  };

  String.prototype.ucFirst = function() {
    return this.replace(/^./, function(m) {
      return m.toUpperCase();
    });
  };
})();
