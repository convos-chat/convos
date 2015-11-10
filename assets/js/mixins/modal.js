(window['mixin'] = window['mixin'] || {})['modal'] = function(proto) {
  var modalTag = false;

  proto.closeModal = function(riotTag, opts) {
    $('#modal_bottom_sheet').closeModal();
    riot.update();
  };

  proto.openModal = function(riotTag, opts) {
    var $target = $('#modal_bottom_sheet');
    if (modalTag) modalTag.unmount(true);
    modalTag = riot.mount($target.get(0), riotTag, opts || {})[0];
    if ($('.lean-overlay').length) return;
    $target.openModal({
      complete: function() {
        if (modalTag) modalTag.unmount(true);
        modalTag = false;
      }
    });
  };
};
