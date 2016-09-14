(function() {
  // *foo*     or _foo_     = <em>foo</em>
  // **foo**   or __foo__   = <strong>foo</strong>
  // ***foo*** or ___foo___ = <em><strong>foo</strong></em>
  // \*foo*    or \_foo_    = *foo* or _foo_

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

  var text2emojiRe = Object.keys(text2emoji).map(function(s) { return s.replace(/([\(\)])/g, "\\$1"); }).join("|");
  var codeToHtmlRe = new RegExp("(\\\\?)`([^`]+)`", "g");
  var mdToHtmlRe = new RegExp("(^|\\s)(\\\\?)(\\*+|_+)(\\w.*?)\\3", "g");

  text2emojiRe = new RegExp("(^|\\s)(" + text2emojiRe + ")(?=\\s|$)", "i");

  Vue.filter("markdown", function(str, args) {
    if (!args) args = {emoji: true};
    if (args.escape) str = str.xmlEscape();

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

    str = str.replace(codeToHtmlRe, function(all, esc, text) {
      return esc ? all.replace(/^\\/, "") : "<code>" + text + "</code>";
    });

    if (args.emoji) {
      str = str.replace(text2emojiRe, function(m, pre, emoji) {
        return pre + (text2emoji[emoji] || emoji);
      });
      str = emojione.toImage(str);
    }

    if (args.links) str = str.autoLink({target: "_blank"});

    return str;
  });
})();
