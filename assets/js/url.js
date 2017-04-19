((function() {
  var encode = function(s) {
    return encodeURIComponent(s).replace(/'/g, "%27");
  };

  // decodeURIComponent() fails on invalid URLs, where this code pass
  var decode = function(s) {
    s = s.replace(/\+/g, " ");

    s = s.replace(
      /%([ef][0-9a-f])%([89ab][0-9a-f])%([89ab][0-9a-f])/gi,
      function(code, hex1, hex2, hex3) {
        var n1 = parseInt(hex1, 16) - 0xE0;
        var n2 = parseInt(hex2, 16) - 0x80;
        if (n1 === 0 && n2 < 32) return code;
        var n3 = parseInt(hex3, 16) - 0x80;
        var n = (n1 << 12) + (n2 << 6) + n3;
        return n > 0xFFF ? code : String.fromCharCode(n);
      }
    );

    s = s.replace(
      /%([cd][0-9a-f])%([89ab][0-9a-f])/gi,
      function(code, hex1, hex2) {
        var n1 = parseInt(hex1, 16) - 0xC0;
        if (n1 < 2) return code;
        var n2 = parseInt(hex2, 16) - 0x80;
        return String.fromCharCode((n1 << 6) + n2);
      }
    );

    return s.replace(/%([0-7][0-9a-f])/gi,
      function(code, hex) {
        return String.fromCharCode(parseInt(hex, 16));
      }
    );
  };

  window.Url = function(url) {
    var tmp, link = document.createElement("a");

    // let the browser parse (most) of the URL
    if (!arguments.length) url = location.href;
    link.href = url.replace(/^\w+:/, "http:");

    // protocol
    tmp = url.match(/^(\w+):/);
    this.protocol = tmp ? tmp[1] : "";

    // host, port, fragment
    this.host = link.hostname == "0.0.0.0" ? "" : link.hostname; // experimental special case
    this.port = link.port;
    this.fragment = decode(link.hash.replace(/^#/, ""));

    // username:password
    if (tmp = url.match(/\/\/(.*?)(?::(.*?))?@/)) {
      this.user = decode(tmp[1] || "");
      this.pass = decode(tmp[2] || "");
    }

    // path
    tmp = link.pathname.replace(/^\//, "");
    this.path = tmp.length ? tmp.split("/") : [];

    // query string (not in order)
    this.query = tmp = {};
    link.search.replace(/^\?/, "").split("&").filter(function(kv) {
      return kv.length
    }).forEach(function(kv) {
      kv = kv.split("=");
      if (!tmp[kv[0]]) tmp[kv[0]] = [];
      tmp[kv[0]].push(decode(kv[1]));
    });
  };

  var proto = Url.prototype;

  proto.decode = decode;
  proto.encode = encode;

  proto.param = function(name) {
    if (arguments.length == 2) this.query[name] = arguments[1].forEach ? arguments[1] : [arguments[1]];
    var p = this.query[name];
    return p ? p[0] : undefined;
  };

  proto.everyParam = function(name) {
    if (arguments.length == 2) this.query[name] = arguments[1];
    return this.query[name] || [];
  };

  proto.names = function() {
    return Object.keys(this.query).sort();
  };

  proto.queryAsString = function() {
    var query = [];

    this.names().forEach(function(k) {
      this.query[k].forEach(function(v) {
        query.push(k + "=" + encodeURIComponent(v));
      });
    }.bind(this));

    return query.join("&");
  };

  proto.removeParam = function(name) {
    delete this.query[name];
    return this;
  };

  proto.toString = function() {
    var self = this;
    var names = this.names();
    var url = [];

    url.push(this.protocol ? this.protocol + "://" : "//");
    if (this.user) url.push(encode(this.user));
    if (this.pass) url.push(":" + encode(this.pass));
    if (this.user || this.pass) url.push("@");
    if (this.host) url.push(this.host);
    if (this.port) url.push(":" + this.port);
    if (this.path.length) url.push("/" + this.path.join("/"));
    if (this.names().length) url.push("?" + this.queryAsString());
    if (this.fragment) url.push("#" + this.fragment);

    return url.length == 1 ? "" : url.join("");
  };
})());
