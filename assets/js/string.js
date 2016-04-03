(function() {
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
    return numbers[this] || this;
  };

  var urlRe = new RegExp("^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?");
  String.prototype.parseUrl = function() {
    var m = this.match(urlRe);
    if (!m) return {};
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

  var xml = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  };
  String.prototype.xmlEscape = function() {
    return this.replace(/[&<>"']/g, function(m) {
      return xml[m];
    });
  };
})();
