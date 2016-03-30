<dialog-container>
  <header>
    <div class="actions" if={dialog.hasConnection()}>
      <a href="#info" onclick={getInfo} class="tooltipped" title="Get information"><i class="material-icons">info_outline</i></a>
      <!-- a href="#search" class="tooltipped" title="Search"><i class="material-icons">search</i></a -->
      <a href="#close" onclick={removeDialog} class="tooltipped" title="Close dialog"><i class="material-icons">close</i></a>
    </div>
    <div class="actions" if={!dialog.hasConnection()}>
      <a href="#chat"><i class="material-icons">star_rate</i></a>
    </div>
    <h5 class="tooltipped" title={dialog.topic() || 'No topic is set.'}>{dialog.name()}</h5>
  </header>
  <main name="scrollElement">
    <dialog-message dialog={parent.dialog} msg={msg} user={parent.user} each={msg, i in messages}/>
  </main>
  <user-input dialog={dialog} user={user}/>
  <script>
  var tag = this;
  mixin.bottom(this); // uses name="scrollElement"
  mixin.numbers(this);
  mixin.time(this);

  this.user = opts.user;
  this.dialog = this.user.currentDialog();
  this.currentDialog = this.dialog.id();
  this.messages = [];

  getInfo(e) {
    this.dialog.participants(function(err, res) {
      var participants = res.participants;
      var message = err ? err[0].message : '';

      if (!message) {
        message += tag.numberAsString(participants.length).ucFirst();
        message += ' participants in ' + this.name() + ' connected to ';
        message += this.connection().name() + ': ';
        message += participants.map(function(p, i) { return p.mode + p.name; }).join(', ');
      }

      this.trigger('message', {
        type: err ? 'error' : 'notice',
        from: this.connection().name(),
        message: message
      });
    });
  }

  removeDialog(e) {
    this.user.removeDialog(this.dialog, function(err) {
      if (err) this.dialog.trigger('message', {message: err[0].message});
      riot.update();
    });
  }

  this.on('update', function() {
    this.dialog = this.user.currentDialog();
    this.messages = this.dialog.messages();
    this.prevMessage = null;

    if (this.dialog.id() != this.currentDialog) {
      this.currentDialog = this.dialog.id();
      this.dialog.trigger('show');
    }
  });
  </script>
</dialog-container>
