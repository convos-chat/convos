(function() {
  var ONE_MINUTE = 60;
  var ONE_HOUR   = ONE_MINUTE * 60;
  var ONE_DAY    = ONE_HOUR * 24;

  Vue.filter("timestring", function(ts) {
    if (!ts) return "";
    if (typeof ts == "string")
      ts = new Date(ts);

    var now       = new Date().epoch();
    var yesterday = now - (now % 86400);
    var tomorrow  = now + 86400 - (now % 86400);
    var s         = ts.epoch();

    if (s > tomorrow + 86400) return ts.getDate() + ". " + ts.getAbbrMonth() + " " + ts.getHM();
    if (s > yesterday) return ts.getHM();
    if (s > now - ONE_DAY * 31) return ts.getDate() + ". " + ts.getAbbrMonth() + " " + ts.getHM();

    return ts.getDate() + ". " + ts.getAbbrMonth() + " " + ts.getFullYear();
  });

  // 1h 4m 2s
  Vue.filter("seconds", function(s) {
    var x, str = [];
    if (!s) return "0s";
    if (typeof s == "string" && s.match(/^[a-z]/i)) return s; // In case of "Not loaded" as input
    if (s > ONE_DAY) {
      x = parseInt(s / ONE_DAY);
      s -= x * ONE_DAY;
      str.push(x + "d");
    }
    if (s > ONE_HOUR) {
      x = parseInt(s / ONE_HOUR);
      s -= x * ONE_HOUR;
      str.push(x + "h");
    }
    if (s > ONE_MINUTE) {
      x = parseInt(s / ONE_MINUTE);
      s -= x * ONE_MINUTE;
      str.push(x + "m");
    }
    if (str.length < 3 && (!str.length || s)) {
      str.push(s + "s");
    }
    return str.join(" ");
  });
})();
