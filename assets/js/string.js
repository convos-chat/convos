(function() {
  // *foo*     or _foo_     = <em>foo</em>
  // **foo**   or __foo__   = <strong>foo</strong>
  // ***foo*** or ___foo___ = <em><strong>foo</strong></em>
  // \*foo*    or \_foo_    = *foo* or _foo_
  var mdToHtmlRe = new RegExp('(\\\\?)(\\*+|_+)(\\w.*?)\\2', 'g');
  String.prototype.mdToHtml = function() {
    return this.replace(mdToHtmlRe, function(all, esc, tag, text) {
      switch (tag.length) {
        case 1: return esc ? all.replace(/^\\/, '') : '<em>' + text + '</em>';
        case 2: return esc ? all.replace(/^\\/, '') : '<strong>' + text + '</strong>';
        case 3: return esc ? all.replace(/^\\/, '') : '<em><strong>' + text + '</strong></em>';
        default: return all;
      }
    });
  };

  var urlRe = new RegExp("^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?");
  String.prototype.parseUrl = function() {
    var m = this.match(urlRe);
    if (!m) return {};
    var s = {scheme: m[2], authority: m[4], path: m[5], fragment: m[9], query: {}};
    var p = m[4].split('@', 2);
    s.hostPort = p[1] || p[0];
    s.userinfo = p.length == 2 ? p[0].split(':', 2) : [];
    p = m[7] ? m[7].split('&') : [];
    p.forEach(function(i) { var kv = i.split('=', 2); s.query[kv[0]] = kv[1]; });
    return s;
  };

  String.prototype.ucFirst = function() {
    return this.replace(/^./, function(m) { return m.toUpperCase(); });
  };

  var xml = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    '\'': '&#39;'
  };
  String.prototype.xmlEscape = function() {
    return this.replace(/[&<>"']/g, function(m) { return xml[m]; });
  };
})();
