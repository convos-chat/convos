riot.tag2('dialog-container', '<header> <div class="actions" if="{dialog._connection}"> <a href="#settings"><i class="material-icons">more_horiz</i></a> <a href="#people"><i class="material-icons">people</i></a> <a href="#search"><i class="material-icons">search</i></a> <a href="#close" if="{n_tabs}"><i class="material-icons">close</i></a> </div> <div class="actions" if="{!dialog._connection}"> <a href="#chat"><i class="material-icons">star_rate</i></a> </div> <h5>{dialog.name()}</h5> <p class="topic truncate" if="{dialog.topic()}">{dialog.topic()}</p> </header> <main name="scrollElement"> <ol class="collection"> <li class="collection-item" each="{messages}"> <a href="{\'#autocomplete:\' + from}" class="title">{from}</a> <dialog-message ts="{ts}" message="{message}" each="{nested_messages}"></dialog-message> <span class="secondary-content ts" title="{ts.toISOString()}">{parent.timestring(ts)}</span> </li> </ol> </main> <user-input dialog="{dialog}"></user-input>', '', '', function(opts) {
  mixin.bottom(this);
  mixin.time(this);

  this.dialog = opts.dialog;
  this.currentDialog = this.dialog.id();
  this.lastNumberOfMessages = 0;
  this.messages = [];

  this.on('update', function() {
    var list = this.dialog.messages();
    var messages = [];
    var prev = null;

    if (this.dialog.id() != this.currentDialog) {
      this.currentDialog = this.dialog.id();
      this.dialog.trigger('show');
    }
    if (this.lastNumberOfMessages == list.length) {
      return;
    }

    this.messages = messages;
    this.lastNumberOfMessages = list.length;
    list.forEach(function(msg) {
      if (!msg.hr && prev && msg.from == prev.from && msg.ts.epoch() < prev.ts.epoch() + 300) {
        prev.nested_messages.push(msg);
      }
      else {
        messages.push(msg);
        msg.nested_messages = [msg];
        prev = msg;
      }
    });
  });
}, '{ }');
