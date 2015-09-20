(window['mixin'] = window['mixin'] || {})['form'] = function(proto) {
  proto.submitting = false;

  proto.formInvalidInput = function(errors) {
    (errors || []).forEach(function(err) {
      var name = err.path.replace(/\/data\//g, '') || '';
      var field = this.root.querySelector('input[name="' + name + '"]');
      if (field) {
        field.setAttribute('title', err.message);
        field.classList.add('invalid');
        field.focus();
      }
      else {
        this.errors = errors;
      }
    }.bind(this));
    return this;
  };

  proto.formSaved = function() {
    this.saving = false;

    if (!this._formSavedHandlerInstalled) {
      this._formSavedHandlerInstalled = true;
      $('input', this.root).change(function() {
        $(this).closest('form').find('button[type="submit"]').each(function() {
          $(this).html('Save <i class="material-icons right">save</i>');
        });
      });
    }

    $('button[type="submit"]', this.root).each(function() {
      $(this).html('Saved <i class="material-icons right">done</i>');
    });

    return this;
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

  proto.updateTextFields = function() {
    var input_selector = 'input[type=text], input[type=password], input[type=email], input[type=url], input[type=tel], input[type=number], input[type=search], textarea';
    $(input_selector, this.root).each(function(index, element) {
      if ($(element).val().length > 0 || $(this).attr('placeholder') !== undefined || $(element)[0].validity.badInput === true) {
        $(this).siblings('label, i').addClass('active');
      }
      else {
        $(this).siblings('label, i').removeClass('active');
      }
    });
  };

  return proto;
};
