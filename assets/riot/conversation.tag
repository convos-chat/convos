<conversation>
  <div class="conversation-container">
    <div class="actions">
      <a href="#settings"><i class="material-icons">more_horiz</i></a>
      <a href="#people"><i class="material-icons">people</i></a>
      <a href="#search"><i class="material-icons">search</i></a>
      <a href="#close"><i class="material-icons">close</i></a>
    </div>
    <h5>{conversation.name()}</h5>
    <ol class="conversation collection">
      <li class="collection-item" each={messages}>
        <a href={'#autocomplete:' + from} class="title">{from}</a>
        <conversation-message ts={ts} message={message} each={messages}/>
        <span class="secondary-content ts" title={ts}>{parent.timestring(ts)}</span>
      </li>
    </ol>
  </div>
  <user-input conversation={conversation} />
  <script>

  mixin.time(this);

  var prev = null;
  this.conversation = opts.conversation || new Convos.Conversation();
  this.messages = [];
  this.n = 0;

  avatar(from) {
    return 'https://robohash.org/' + from + '.png';
  }

  defaultMessages() {
    return [
      {from: 'convosbackend', message: 'Loading messages...', ts: new Date().toISOString()}
    ];
  }

  this.on('update', function() {
    var o_messages = this.conversation.messages();
    if (!o_messages.length) o_messages = this.defaultMessages();
    if (this.n == o_messages.length) return;
    this.messages = [];
    this.n = o_messages.length;
    o_messages.forEach(function(m) {
      if (prev && m.from == prev.from) {
        prev.messages.push(m);
      }
      else {
        this.messages.push(m);
        m.messages = [m];
        prev = m;
      }
    }.bind(this));
  });

  </script>
</conversation>
