(window['mixin'] = window['mixin'] || {})['http'] = function(proto) {
  var cache = window.mixin.http.cache = window.mixin.http.cache || {};

  (function() {
    var limit = new Date() / 1000 - 60;
    Object.keys(cache).sort(function(a, b) { return cache[a]._ts - cache[b]._ts }).forEach(function(k) {
      if (cache[k]._ts < limit) delete cache[k];
    });
  })();

  var makeErr = function(xhr) {
    var errors = xhr.responseJSON.errors || [];
    if (xhr.status == 200) return false;
    if (errors.length) return errors;
    if (!xhr.status) xhr.status = 'No response';
    return [{message: "Something very bad happened! Try again later. (" + xhr.status + ")", path: xhr.url}];
  };

  window.urlWithQueryString = window.urlWithQueryString || function(url, query) {
    var str = [];

    for (var k in query) {
      str.push(encodeURIComponent(k) + '=' + encodeURIComponent(query[k]));
    }

    return [url, str.join('&')].join('?').replace(/\?$/, '');
  };

  proto.httpCachedGet = function(url, query, cb) {
    var xhr = this.httpIsCached(url, query);
    if (xhr) {
      cb.call(this, makeErr(xhr), xhr);
    }
    else {
      this.httpGet(url, query, cb);
    }
    return this;
  };

  proto.httpDelete = function(url, query, cb) {
    var xhr = new XMLHttpRequest();
    xhr.url = window.urlWithQueryString(url, query);
    xhr.open('DELETE', xhr.url);
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) return;
      xhr._ts = new Date().getTime() / 1000;
      xhr.responseJSON = xhr.responseText.match(/^[\{\[]/) ? JSON.parse(xhr.responseText) : {};
      if (window.DEBUG) console.log(['DELETE', xhr.url, xhr.status, xhr.responseJSON || xhr.responseText]);
      if (xhr.status == 200) cache[xhr.url] = xhr;
      cb.call(this, makeErr(xhr), xhr);
    }.bind(this);
    xhr.send(null);
  };

  proto.httpGet = function(url, query, cb) {
    var xhr = new XMLHttpRequest();
    xhr.url = window.urlWithQueryString(url, query);
    xhr.open('GET', xhr.url);
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) return;
      xhr._ts = new Date().getTime() / 1000;
      xhr.responseJSON = xhr.responseText.match(/^[\{\[]/) ? JSON.parse(xhr.responseText) : {};
      if (window.DEBUG) console.log(['GET', xhr.url, xhr.status, xhr.responseJSON || xhr.responseText]);
      if (xhr.status == 200) cache[xhr.url] = xhr;
      cb.call(this, makeErr(xhr), xhr);
    }.bind(this);
    xhr.send(null);
  };

  proto.httpIsCached = function(url, query) {
    return cache[window.urlWithQueryString(url, query)];
  };

  proto.httpPost = function(url, data, cb) {
    var xhr = new XMLHttpRequest();
    xhr.url = url;
    xhr.open('POST', xhr.url);
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) return;
      xhr.responseJSON = xhr.responseText.match(/^[\{\[]/) ? JSON.parse(xhr.responseText) : {};
      if (window.DEBUG) console.log(['POST', xhr.url, xhr.status, xhr.responseJSON || xhr.responseText]);
      cb.call(this, makeErr(xhr), xhr);
    }.bind(this);
    xhr.send(typeof data == 'object' ? JSON.stringify(data) : data);
  };

  return proto;
};
