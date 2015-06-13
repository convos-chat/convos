(window['mixin'] = window['mixin'] || {})['modal'] = function(caller) {
  var modalTag = false;

  caller.closeModal = function(riotTag, opts) {
    $('#modal_bottom_sheet').closeModal();
  };

  caller.openModal = function(riotTag, opts) {
    var $target = $('#modal_bottom_sheet');
    if (modalTag) modalTag.unmount(true);
    modalTag = riot.mountTo($target.get(0), riotTag, opts || {});
    if ($('.lean-overlay').length) return;
    $target.openModal({
      complete: function() {
        if (modalTag) modalTag[0].unmount(true);
        modalTag = false;
      }
    });
  };
};
