(window['mixin'] = window['mixin'] || {})['http'] = function(proto) {
  var cache = window.mixin.http.cache = window.mixin.http.cache || {}; // global cache

  var err = function(xhr) {
    var errors = xhr.responseJSON.errors || [];
    if (xhr.status == 200) return false;
    if (errors.length) return errors;
    return [{message: "Ooops! Try again later. (" + xhr.status + ")", path: xhr.url}];
  };

  var urlWithQueryString = function(url, query) {
    var str = [];
    for (var k in query) str.push(encodeURIComponent(k) + '=' + encodeURIComponent(query[k]));
    return [url, str.join('&')].join('?').replace(/\?$/, '');
  };

  proto.httpCachedGet = function(url, query, cb) {
    var xhr = cache[urlWithQueryString(url, query)];
    if (xhr) {
      cb.call(this, xhr.status == 200 ? '' : xhr.status, xhr);
    }
    else {
      this.httpGet(url, query, function(err, xhr) {
        if (!err) cache[xhr.url] = xhr;
        cb.call(this, xhr.status == 200 ? '' : xhr.status, xhr);
      }.bind(this));
    }
  };

  proto.httpGet = function(url, query, cb) {
    var xhr = new XMLHttpRequest();
    xhr.url = urlWithQueryString(url, query);
    xhr.open('GET', xhr.url);
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) return;
      xhr.responseJSON = xhr.responseText.match(/^[\[\{]/) ? JSON.parse(xhr.responseText) : {};
      if (window.DEBUG) console.log(['GET', xhr.url, xhr.status, xhr.responseJSON]);
      if (xhr.status == 200 && cache[xhr.url]) cache[xhr.url] = xhr;
      cb.call(this, err(xhr), xhr);
    }.bind(this);
    xhr.send(null);
  };

  proto.httpPost = function(url, data, cb) {
    var xhr = new XMLHttpRequest();
    xhr.url = url;
    xhr.open('POST', xhr.url);
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) return;
      xhr.responseJSON = xhr.responseText.match(/^[\[\{]/) ? JSON.parse(xhr.responseText) : {};
      if (window.DEBUG) console.log(['POST', xhr.url, xhr.status, xhr.responseJSON]);
      cb.call(this, err(xhr), xhr);
    }.bind(this);
    xhr.send(typeof data == 'object' ? JSON.stringify(data) : data);
  };

  return proto;
};
