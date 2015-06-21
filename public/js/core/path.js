(function(window) {
  Convos.Path = function(str) {
    this.path = str.split('/');
  };

  var proto = Convos.Path.prototype;

  proto.connection = function() { return this.path[3]; };
  proto.conversation = function() { return this.path[4]; };
  proto.email = function() { return this.path[1]; };
  proto.protocol = function() { return this.path[2]; };

  proto.messagesUrl = function() { return apiUrl(['connection', this.protocol(), this.connection(), 'conversation', this.conversation(), 'messages']); };
})(window);
