var Router = {
  routes: [],
  isCurrentUrl: function(q) {
    return Router.url().path.match(q);
  },
  add: function(re, fn) {
    var handler = typeof fn == 'function' ? fn : function() { Router.render(fn); };
    Router.routes.push({ re: re, handler: handler});
    return Router;
  },
  dispatch: function() {
    var url = Router.url();
    for (var i = 0; i < Router.routes.length; i++) {
      var match = url.path.match(Router.routes[i].re);
      if (!match) continue;
      match.shift();
      Router.routes[i].handler.call({}, match, url.query);
      return;
    }
    console.log("No match for path '" + url.path + "'");
    return;
  },
  render: function(riotTag, opts) {
    var tag, domNode = document.getElementById('app');
    if (document.body.className == riotTag) {
      console.log('update: ' + riotTag);
      Router.mountedNodes.forEach(function(node) { node.update(); });
      return;
    }
    document.body.className = riotTag;
    domNode.innerHTML = '';
    console.log('render: ' + riotTag);
    if (Router.mountedNodes) Router.mountedNodes.forEach(function(node) { node.unmount(true); });
    tag = Router.mountedNodes = riot.mountTo(domNode, riotTag, opts || {});
    Router.afterRender(opts);
    return tag;
  },
  route: function(path) {
    if (!path) return Router.dispatch();
    riot.route(path);
  },
  start: function(cb) {
    if (cb) Router.afterRender = cb;
    riot.route.stop();
    window.addEventListener ? window.addEventListener('hashchange', Router.dispatch, false) : window.attachEvent('onhashchange', Router.dispatch);
  },
  url: function(url) {
    if (!url) url = (location.href.match(/.*?\#(.*)/) || ['', ''])[1];
    var query = {};
    url = url.split('?');
    if (url[1]) url[1].replace(/\+/g, ' ').split('&').forEach(function(i) { var kv = i.split('='); query[kv[0]] = kv[1]; });
    return {path: url[0], query: query};
  }
};
