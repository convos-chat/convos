(function() {
  // *foo*     or _foo_     = <em>foo</em>
  // **foo**   or __foo__   = <strong>foo</strong>
  // ***foo*** or ___foo___ = <em><strong>foo</strong></em>
  // \*foo*    or \_foo_    = *foo* or _foo_

  var mdToHtmlRe = new RegExp("(^|\\s)(\\\\?)(\\*+|_+)(\\w.*?)\\3", "g");
  Vue.filter("markdown", function(str) {
    return str.replace(mdToHtmlRe, function(all, b, esc, tag, text) {
      switch (tag.length) {
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
  });
})();
