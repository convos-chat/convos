Date.prototype.epoch = function() {
  return this.getTime() / 1000;
};

Date.prototype.getAbbrMonth = function() {
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

Date.prototype.getHM = function() {
  return [this.getHours(), this.getMinutes()].map(function(v) { return v < 10 ? '0' + v : v; }).join(':');
};
