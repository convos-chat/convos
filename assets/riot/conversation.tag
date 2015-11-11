<conversation>
  <ul class="conversation collection">
    <li class="collection-item avatar" each={conversation}>
      <img src={parent.avatar(from)} alt="" class="circle">
      <a href={'#autocomplete:' + from} class="title">{from}</a>
      <conversation-message ts={ts} message={message} each={messages}/>
      <span class="secondary-content ts" title={ts}>{parent.timestring(ts)}</span>
    </li>
  </ul>
  <script>

  mixin.time(this);

  var prev = null;
  this.conversation = [];
  this.n = 0;

  avatar(from) {
    return 'https://robohash.org/' + from + '.png';
  }

  this.on('update', function() {
    var o_messages = opts.conversation.messages();
    if (this._c != opts.conversation) this._c = opts.conversation.trigger('show');
    if (this.n == o_messages.length) return;
    this.conversation = [];
    this.n = o_messages.length;
    o_messages.forEach(function(m) {
      if (prev && m.from == prev.from) {
        prev.messages.push(m);
      }
      else {
        this.conversation.push(m);
        m.messages = [m];
        prev = m;
      }
    }.bind(this));
  });

  </script>
</conversation>
