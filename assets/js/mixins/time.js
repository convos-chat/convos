(window['mixin'] = window['mixin'] || {})['time'] = function(proto) {
  var ONE_MINUTE = 60;
  var ONE_HOUR = ONE_MINUTE * 60;
  var ONE_DAY = ONE_HOUR * 24;

  proto.timestring = function(ts) {
    if (!ts) return '';
    if (typeof ts == 'string') ts = new Date(ts);
    var now = new Date().epoch();
    var yesterday = now - (now % 86400);
    var tomorrow = now + 86400 - (now % 86400);
    var s = ts.epoch();

    if (s > tomorrow + 86400)    return ts.getDate() + '. ' + ts.getAbbrMonth() + ' ' + ts.getHM();
    if (s > yesterday)           return ts.getHM();
    if (s > now - ONE_DAY * 31)  return ts.getDate() + '. ' + ts.getAbbrMonth() + ' ' + ts.getHM();
    return ts.getDate() + '. ' + ts.getAbbrMonth() + ' ' + ts.getFullYear();
  };

  if (proto['on']) {
    proto.on('updated', function() {
      var self = this;
      $('.ts', this.root).each(function() {
        var $i = $(this);
        $i.text(self.timestring($i.attr('title')));
      });
    });
  }

  return proto;
};
