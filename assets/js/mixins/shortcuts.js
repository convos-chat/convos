(window['mixin'] = window['mixin'] || {})['shortcuts'] = function(tag, args) {
  var blacklist = args.blacklist || {input: true, textarea: true, select: true};
  var special = {9: 'tab', 27: 'esc'};

  var keypress = function(e) {
    var target = document.activeElement || e.target;
    var tagName = target.tagName.toLowerCase();
    var key = special[e.keyCode] || String.fromCharCode(e.charCode).toLowerCase() || e.keyCode
    var modifier = '';

    if (!special[e.keyCode] && (e.type == 'keydown' || blacklist[tagName])) return
    e.target = target;
    e.tagName = e.target.tagName.toLowerCase();
    if (e.shiftKey) modifier = 'shift+' + modifier;
    if (e.ctrlKey)  modifier = 'ctrl+' + modifier;
    if (e.altKey)   modifier = 'alt+'  + modifier;
    if (e.metaKey)  modifier = 'meta+' + modifier;
    tag.trigger('shortcut_' + modifier + key, e);
  };

  tag._shortcuts = {};

  tag.shortcut = function(keys, cb) {
    keys.split(' ').forEach(function(k) {
      tag.on('shortcut_' + k, function(e) {
        if (cb.call(tag, e) !== true) e.preventDefault();
      });
    });
  };

  tag.on('mount', function() {
    document.addEventListener('keypress', keypress);
    document.addEventListener('keydown', keypress);
  });

  tag.on('unmount', function() {
    document.removeEventListener('keypress', keypress);
    document.addEventListener('keydown', keypress);
  });
};
