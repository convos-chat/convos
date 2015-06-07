(window['mixin'] = window['mixin'] || {})['http'] = function(caller) {
  var cache = window.mixin.http.cache = window.mixin.http.cache || {}; // global cache

  var handlerError = function(xhr) {
    this.errors = xhr.responseJSON.errors || [];
    if (xhr.status != 200 && !this.errors.length) this.errors = [{message: 'Unknown error. (' + xhr.status + ')'}];
  };

  var urlWithQueryString = function(url, query) {
    var str = [];
    for (var k in query) str.push(encodeURIComponent(k) + '=' + encodeURIComponent(query[k]));
    return [url, str.join('&')].join('?').replace(/\?$/, '');
  };

  // trigger() is added by riot.observable()
  if (!caller.trigger) riot.observable(caller);

  caller.httpCachedGet = function(url, query, cb) {
    var xhr = cache[urlWithQueryString(url, query)];
    if (xhr) {
      cb.call(this, xhr.status == 200 ? '' : xhr.status, xhr);
    }
    else {
      this.httpGet(url, query, function(err, xhr) {
        if (!err) cache[xhr.url] = xhr;
        cb.call(this, xhr.status == 200 ? '' : xhr.status, xhr);
      });
    }
  }.bind(caller);

  caller.httpGet = function(url, query, cb) {
    var xhr = new XMLHttpRequest();
    xhr.url = urlWithQueryString(url, query);
    xhr.open('GET', xhr.url);
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) return;
      xhr.responseJSON = xhr.responseText.match(/^[\[\{]/) ? JSON.parse(xhr.responseText) : {};
      if (window.DEBUG) console.log(['GET', xhr.url, xhr.status, xhr.responseJSON]);
      if (xhr.status == 200 && cache[xhr.url]) cache[xhr.url] = xhr;
      handlerError.call(this, xhr);
      cb.call(this, xhr.status == 200 ? '' : xhr.status, xhr);
    }.bind(this);
    xhr.send(null);
  }.bind(caller);

  caller.httpPost = function(url, data, cb) {
    var xhr = new XMLHttpRequest();
    xhr.url = url;
    xhr.open('POST', xhr.url);
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) return;
      xhr.responseJSON = xhr.responseText.match(/^[\[\{]/) ? JSON.parse(xhr.responseText) : {};
      if (window.DEBUG) console.log(['POST', xhr.url, xhr.status, xhr.responseJSON]);
      handlerError.call(this, xhr);
      cb.call(this, xhr.status == 200 ? '' : xhr.status, xhr);
    }.bind(this);
    xhr.send(typeof data == 'object' ? JSON.stringify(data) : data);
  }.bind(caller);

  caller.httpRefresh = function(name, method) {
    if (typeof name == 'object') name = name.target.getAttribute('data-refresh-name');
    this[method || 'httpGet'].apply(
      this,
      this.fetchOnMount[name].concat(function(err, xhr) {
        for (var k in xhr.responseJSON) this[k] = xhr.responseJSON[k];
        this.update();
      })
    );
  };

  caller.on('mount', function() {
    for (var name in (this.fetchOnMount || {})) caller.httpRefresh(name, 'httpCachedGet');
  });

  return caller;
};
