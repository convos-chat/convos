(window['mixin'] = window['mixin'] || {})['time'] = function(proto) {
  var ONE_MINUTE = 60;
  var ONE_HOUR = ONE_MINUTE * 60;
  var ONE_DAY = ONE_HOUR * 24;

  var extendedDate = function(str) {
    var t = new Date(str);

    t.getAbbrMonth = function() {
      switch(this.getMonth()) {
        case 0: return 'Jan';
        case 1: return 'Feb';
        case 2: return 'March';
        case 3: return 'Apr';
        case 4: return 'May';
        case 5: return 'Jun';
        case 6: return 'July';
        case 7: return 'Aug';
        case 8: return 'Sept';
        case 9: return 'Oct';
        case 10: return 'Nov';
        case 11: return 'Dec';
      }
    };

    t.getHm = function() {
      return [this.getHours(), this.getMinutes()].map(function(v) { return v < 10 ? '0' + v : v; }).join(':');
    };

    return t;
  };

  proto.timestring = function(ts) {
    if (!ts) return '';
    var now = new Date().getTime() / 1000;
    var yesterday = now - (now % 86400);
    var tomorrow = now + 86400 - (now % 86400);
    var s;

    ts = extendedDate(ts);
    s = ts.getTime() / 1000;

    if (s > tomorrow + 86400)    return ts.getDate() + '. ' + ts.getAbbrMonth() + ' ' + ts.getHm();
    if (s > yesterday)           return ts.getHm();
    if (s > now - ONE_DAY * 31)   return ts.getDate() + '. ' + ts.getAbbrMonth() + ' ' + ts.getHm();
    return ts.getDate() + '. ' + ts.getAbbrMonth() + ' ' + ts.getFullYear();
  };

  if (proto['on']) {
    proto.on('updated', function() {
      var self = this;
      $('.ts', this.root).each(function() {
        var $i = $(this);
        $i.text(self.timestring(1 * $i.attr('title')));
      });
    });
  }

  return proto;
};
