// This code is based on https://github.com/bryanwoods/autolink-js
// Originally writen by Bryan Woods.
(function() {
  var n = 0;

  var email = function(str, args, attrs) {
    // Poor man's email regexp
    return str.replace(email.pattern, function(m, addr) {
      var id = 'auto_link_' + (++n);
      if (args.after) args.after(addr, id) || '';
      return '<a href="mailto:' + addr + '"' + attrs + ' id="' + id + '">' + addr + '</a>';
    })
  };

  var url = function(str, args, attrs) {
    return str.replace(url.pattern, function(m, pre, addr) {
      var id = 'auto_link_' + (++n);
      if (args.after) args.after(addr, id) || '';
      return pre + '<a href="' + addr + '"' + attrs + ' id="' + id + '">' + addr + '</a>';
    });
  };

  email.pattern = /(\w[a-z_.-]+\@\S+\.\w+)/gi;
  url.pattern = /(^|\W|[\s\n]|<br\/?>)((?:https?|ftp):\/\/[\-A-Z0-9+\u0026\u2019@#\/%?=()~_|!:,.;]*[\-A-Z0-9+\u0026@#\/%=~_|])/gi;

  String.prototype['autoLink'] = function(args) {
    var k, linkAttributes, v;

    linkAttributes = ((function() {
      var _results;
      _results = [];
      for (k in args) {
        v = args[k];
        if (typeof v !== 'function') _results.push(' ' + k + '="' + v + '"');
      }
      return _results;
    })()).join('');

    return this.replace(/\S+/g, function(str) {
      return str.match(/^\S*(https?|ftp)/) ? url(str, args, linkAttributes)
           : str.match(/\@/)               ? email(str, args, linkAttributes)
           : str;
    });
  };
})();
