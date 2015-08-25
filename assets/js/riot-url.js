(function(window) {
  riot.url = function() {}; // to be decided

  // Allow riot.url.on('update', function(url) {
  //   if (url.base.match(/.../)) ...
  //   if (url.path.match(/^whatever/)) ...
  //   if (url.query.whatever) ...
  // });
  riot.observable(riot.url);

  // targetObject = riot.url.parse("http://example.com/#path?a=1&b=2", targetObject);
  // res = riot.url.parse("http://example.com/#path?a=1&b=2#yikes");
  // res = riot.url.parse("path?a=1&b=2");
  riot.url.parse = function(url, target) {
    if (!target) target = {};
    var base = url.indexOf('http') == 0 ? url.split('#') : ['', url];
    var str = (base[1] || '').split('?'); // ['some/path', 'a=1&b=2']
    target._raw = base[1];
    target.base = base[0].replace(/\/$/, '');
    target.hash = base[2] || '';
    target.path = str[0];
    target.query = {};
    if (str[1]) str[1].split('&').forEach(function(i) { var kv = i.split('='); target.query[kv[0]] = kv[1]; });
    return target;
  };

  // same as riot.route(), but will always trigger "update"
  riot.url.route = function(path) {
    if (path == riot.url._raw) {
      riot.url.trigger('update', riot.url);
    }
    else {
      riot.route(path);
    }
  };

  // Listen for changes in location and update riot
  riot.route(function() {
    riot.url.parse(window.location.href, riot.url);
    riot.url.trigger('update', riot.url);
    riot.update();
  });

  riot.route.start();
  riot.url.parse(window.location.href, riot.url);
})(window);
