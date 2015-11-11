// This code is based on https://github.com/bryanwoods/autolink-js
// Originally writen by Bryan Woods.
String.prototype['autoLink'] = function(args) {
  var k, linkAttributes, v;
  var pattern = /(^|\W|[\s\n]|<br\/?>)((?:https?|ftp):\/\/[\-A-Z0-9+\u0026\u2019@#\/%?=()~_|!:,.;]*[\-A-Z0-9+\u0026@#\/%=~()_|])/gi;
  var markup = '', after = '';

  linkAttributes = ((function() {
    var _results;
    _results = [];
    for (k in args) {
      v = args[k];
      if (typeof v !== 'function') _results.push(" " + k + "='" + v + "'");
    }
    return _results;
  })()).join('');

  markup = this.replace(pattern, function(match, space, url) {
    if (args.after) after += args.after(url) || '';
    return space + "<a href='" + url + "'" + linkAttributes + ">" + url + "</a>";
  });

  return markup + after;
};
