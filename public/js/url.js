(function(window) {
  var parser = document.createElement('a');
  var proto;

  window.parseURL = function(url) {
    parser.href = url.replace(/^(\w+):\/\//, function(a, p) { proto = p; return 'http://'; });

    return {
      fragment: parser.hash.replace(/^\#/, ''),
      host: parser.host.replace(/:\w+$/, ''),
      host_port: parser.host,
      path: parser.pathname,
      port: parser.port,
      query: parser.search.replace(/^\?/, ''),
      scheme: proto,
      toString: function() {
        var url = this.scheme + '://' + this.host;
        if (this.port) url += ':' + this.port;
        if (this.query.length) url += '?' + this.query;
        if (this.fragment.length) url += '#' + this.fragment;
        return url;
      }
    };
  };
})(window);
