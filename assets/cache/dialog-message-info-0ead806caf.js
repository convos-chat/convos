riot.tag2('dialog-message-info', '<h5 class="title">Information</h5> <dl class="horizontal"> <dt>Connection</dt><dd>{dialog.connection().protocol()}-{dialog.connection().name()}</dd> <dt>Topic</dt><dd>{dialog.topic() || \'No topic is set.\'}</dd> <dt>Private</dt><dd>{dialog.is_private() ? \'Yes\' : \'No\'}</dd> </dl> <span class="secondary-content"> <a href="#close" onclick="{parent.removeMessage}"><i class="material-icons">close</i></a> </span>', '', '', function(opts) {
  this.dialog = opts.dialog;
}, '{ }');
