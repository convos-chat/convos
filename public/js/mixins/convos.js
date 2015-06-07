(window['mixin'] = window['mixin'] || {})['convos'] = function(caller) {

  mixin.http(caller);

  mixin.storage(caller, {
    avatar: [function() {return ''}, false],
    email:  [function() {return ''}, false]
  });

  caller.afterRender = function() {
    $('.tooltipped').each(function() {
      var $self = $(this);
      $self.attr('data-tooltip', $self.attr('title') || $self.attr('placeholder')).removeAttr('title');
    }).filter('[data-tooltip]').tooltip();
    Materialize.updateTextFields();
    $('select').material_select();
  };

  caller.updateUser = function(data) {
    if (data.avatar) this.avatar(data.avatar);
    if (data.email) this.email(data.email);
    return this;
  };

  return caller;
};
