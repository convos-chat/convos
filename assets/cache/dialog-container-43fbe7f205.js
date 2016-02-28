riot.tag2('dialog-container', '<header> <div class="actions" if="{dialog.hasConnection()}"> <a href="#settings"><i class="material-icons">more_horiz</i></a> <a href="#people" class="tooltipped" title="List participants"><i class="material-icons">people</i></a> <a href="#search" class="tooltipped" title="Search"><i class="material-icons">search</i></a> <a href="#close" class="tooltipped" title="Close dialog" if="{n_tabs}"><i class="material-icons">close</i></a> </div> <div class="actions" if="{!dialog.hasConnection()}"> <a href="#chat"><i class="material-icons">star_rate</i></a> </div> <h5 class="tooltipped" title="{dialog.topic()}">{dialog.name()}</h5> </header> <main name="scrollElement"> <ol class="collection"> <li class="collection-item" each="{messages}"> <a href="{\'#autocomplete:\' + from}" class="title">{from}</a> <dialog-message ts="{ts}" message="{message}" each="{nested_messages}"></dialog-message> <span class="secondary-content ts" title="{ts.toISOString()}">{parent.timestring(ts)}</span> </li> </ol> </main> <user-input dialog="{dialog}"></user-input>', '', '', function(opts) {
  mixin.bottom(this);
  mixin.time(this);

  this.user = opts.user;
  this.dialog = this.user.currentDialog();
  this.currentDialog = this.dialog.id();
  this.lastNumberOfMessages = 0;
  this.messages = [];

  this.on('update', function() {
    this.dialog = this.user.currentDialog();

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
