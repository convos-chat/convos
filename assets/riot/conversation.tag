<conversation>
  <ul class="conversation collection">
    <li class={'collection-item': true, 'avatar': !parent.same(m, i), 'same': parent.same(m, i)} each={m, i in conversation.messages()}>
      <img src={parent.avatar(m)} alt={m.from} class="circle" if={!parent.same(m, i)}>
      <a href={'#autocomplete:' + m.from} class="title" if={!parent.same(m, i)}>{m.from}</a>
      <div class="message" title={m.ts}>{m.message}</div>
      <span class="secondary-content ts" title={m.ts} if={!parent.same(m, i)}>{timestring(m.ts)}</span>
    </li>
  </ul>
  <script>

  mixin.time(this);

  avatar(m) {
    return m.avatar ? m.avatar : 'https://robohash.org/' + m.from + '.png';
  }

  same(m, i) {
    if (i == 0) return false;
    if (typeof m._same != 'undefined') return m._same;
    return m._same = this.conversation.messages()[i - 1].from == m.from;
  }

  this.on('update', function() {
    if (this.conversation == opts.conversation) return;
    this.conversation = opts.conversation;
    this.conversation.trigger('show');
  });

  </script>
</conversation>
