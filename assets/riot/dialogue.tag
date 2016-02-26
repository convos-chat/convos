<dialogue>
  <div class="dialogue-container">
    <div class="actions" if={dialogue._connection}>
      <a href="#settings"><i class="material-icons">more_horiz</i></a>
      <a href="#people"><i class="material-icons">people</i></a>
      <a href="#search"><i class="material-icons">search</i></a>
      <a href="#close"><i class="material-icons">close</i></a>
    </div>
    <div class="actions" if={!dialogue._connection}>
      <a href="#chat"><i class="material-icons">star_rate</i></a>
    </div>
    <h5>{dialogue.name()}</h5>
    <ol class="dialogue collection">
      <li class="collection-item" each={messages}>
        <a href={'#autocomplete:' + from} class="title">{from}</a>
        <dialogue-message ts={ts} message={message} each={nested_messages}></dialogue-message>
        <span class="secondary-content ts" title={ts.toISOString()}>{parent.timestring(ts)}</span>
      </li>
    </ol>
  </div>
  <user-input dialogue={dialogue} />
  <script>
  mixin.time(this);

  this.dialogue = opts.dialogue;
  this.messages = [];
  this.last_number_of_messages = 0;

  this.on('update', function() {
    var list = this.dialogue.messages();
    var prev = null;
    if (this.last_number_of_messages == list.length) return;
    this.messages = [];
    this.last_number_of_messages = list.length;
    list.forEach(function(msg) {
      if (!msg.hr && prev && msg.from == msg.from && msg.ts.epoch() < prev.ts.epoch() + 120) {
        prev.nested_messages.push(msg);
      }
      else {
        this.messages.push(msg);
        msg.nested_messages = [msg];
        prev = msg;
      }
    }.bind(this));
  });

  </script>
</dialogue>
