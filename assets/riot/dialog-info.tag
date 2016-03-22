<dialog-info>
  <h5 class="title">Information</h5>
  <h5 class="title"></h5>
  <div class="message">
    {numberAsString(participants.length).ucFirst()} participants in {dialog.name()}, connected to
    {dialog.connection().name()}:
    <a href={'#whois:' + p.name} onclick={whois} each={p, i in participants}>
      {p.mode}{p.name}{i + 1 == participants.length ? '.' : ', '}
    </a>
    <br>Topic is {dialog.topic() || 'not set.'}
  </div>
  <span class="secondary-content">
    <a href="#remove" onclick={parent.removeMessage}><i class="material-icons">close</i></a>
  </span>
  <script>
  this.dialog = opts.dialog;
  mixin.numbers(this);

  whois(e) {
    opts.dialog.send('/whois ' + e.item.p.name);
  }

  this.on('update', function() {
    this.participants = opts.dialog.participants();
  });
  </script>
</dialog-info>
