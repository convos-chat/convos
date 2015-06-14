(window['mixin'] = window['mixin'] || {})['form'] = function(proto) {
  proto.submitting = false;

  proto.httpInvalidInput = function(data) {
    var self = this;
    (data.errors || []).forEach(function(err) {
      var name = err.path.replace(/.+\//, '') || '';
      var field = self.root.querySelector('input[name="' + name + '"]');
      if (field) {
        field.setAttribute('title', err.message);
        field.classList.add('invalid');
        field.focus();
      }
      else {
        this.formError = err.message;
      }
    }.bind(this));
  };

  proto.fieldHasInvalidValue = function(field) {
    if (field.pattern && !field.value.match(new RegExp(field.pattern))) {
      field.classList.add('invalid');
      field.focus();
      return 1;
    }
    else {
      field.classList.remove('invalid');
      field.title = '';
      return 0;
    }
  };

  proto.formHasInvalidFields = function() {
    var errors = 0;
    var fields = proto.root.querySelectorAll('input');
    for (i = fields.length; i--;) errors += this.fieldHasInvalidValue(fields[i]);
    return errors;
  };

  return proto;
};
