(function($) {
  var base_url;

  $.fn.atBottom = function() {
    return this.scrollTop() + this.height() >= $('body').height() - 30;
  };
  $.fn.scrollToBottom = function() {
    window.the_machine_is_scrolling = true;
    $('html, body').scrollTop($('body').height());
    window.the_machine_is_scrolling = false;
    return this;
  };
  $.url_for = function() {
    var args = $.makeArray(arguments);
    if(!base_url) base_url = $('script[src$="jquery.js"]').get(0).src.replace(/\/js\/[^\/]+$/, '');
    args.unshift(base_url);
    return args.join('/');
  };

})(jQuery);

(function() {
  var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  var markers = {
    d: [ 'getDate', function(v) { return ("0" + v).substr(-2, 2); } ],
    m: [ 'getMonth', function(v) { return ("0" + v).substr(-2, 2); } ],
    n: [ 'getMonth', function(v) { return months[v]; } ],
    w: [ 'getDay', function(v) { return days[v]; } ],
    y: [ 'getFullYear'],
    H: [ 'getHours', function(v) { return ("0" + v).substr(-2, 2); } ],
    M: [ 'getMinutes', function(v) { return ("0" + v).substr(-2, 2); } ],
    S: [ 'getSeconds', function(v) { return ("0" + v).substr(-2, 2); } ],
    i: [ 'toISOString', null ]
  };

  // Monkeypatching the Date object. This is evil. Almost like ruby...
  Date.prototype.sprintf = function(format) {
    var d = this;
    return format.replace(/%(.)/g, function(m, p) {
      var rv = d[ (markers[p])[0] ]();
      if(markers[p][1] !== null ) rv = markers[p][1](rv);
      return rv;
    });
  };
})();

// https://gist.github.com/3633336
// + caching added by Jan Henning Thorsen
loadScript = function(path, fn) {
  var el = document.createElement('script');
  var loaded = 0;
  var onreadystatechange = 'onreadystatechange';
  var readyState = 'readyState';

  el.id = 'loadScpath_' + path.replace(/\W/g, '_');

  if(document.getElementById(el.id)) {
    return fn();
  }

  el.onload = el.onerror = el[onreadystatechange] = function () {
    if (loaded || (el[readyState] && !(/^c|loade/.test(el[readyState])))) return;
    el.onload = el.onerror = el[onreadystatechange] = null;
    loaded = 1;
    fn();
  };

  el.async = 1;
  el.src = path;
  document.getElementsByTagName('head')[0].appendChild(el);
};

// usage: log('inside coolFunc',this,arguments);
// http://paulirish.com/2009/log-a-lightweight-wrapper-for-consolelog/
window.log = function() {
  log.history = log.history || [];   // store logs to an array for reference
  log.history.push(arguments);
  if(this.console) console.log.apply(
    window.console,
    $.map(arguments, function(e, i) {
      return typeof e === 'string' ? e : JSON.stringify(e);
    })
  );
};
