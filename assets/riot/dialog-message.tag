<dialog-message>
  <span if={msg.type == 'action'}>✧</span>
  <a href={'#insert:' + msg.from} class="title" onclick={insertIntoInput} if={!msg.special}>{msg.from}</a>
  <div class="message" if={!msg.special}></div>
  <div class="error" if={msg.special == 'error'}>{msg.message}</div>
  <div class="info" if={msg.special == 'info'}>
    <h5 class="title">Information</h5>
    <dl class="horizontal">
      <dt>Connection</dt><dd>{dialog.connection().protocol()}-{dialog.connection().name()}</dd>
      <dt>Topic</dt><dd>{dialog.topic() || 'No topic is set.'}</dd>
      <dt>Private</dt><dd>{dialog.is_private() ? 'Yes' : 'No'}</dd>
    </dl>
  </div>
  <div class="users" if={msg.special == 'users'}>
    <h5 class="title">Participants ({users.length})</h5>
    <span if={!users.length}>No participants. You need to join the dialog first.</span>
    <a href={'#insert:' + u.name} onclick={insertIntoInput} each={u, i in users}>
      {u.mode}{u.name}{i+1 == users.length ? '.' : ', '}
    </a>
  </div>
  <span class="secondary-content" if={msg.special}>
    <a href="#close" onclick={removeMessage}><i class="material-icons">close</i></a>
  </span>
  <span class="secondary-content ts tooltipped" title={msg.ts.toLocaleString()} if={!msg.special}>
    {timestring(msg.ts)}
  </span>
  <script>
  var tag = this;
  mixin.time(this);

  this.dialog = opts.dialog;
  this.msg = opts.msg;
  this.user = opts.user;
  this.users = [];

  insertIntoInput(e) {
    this.user.trigger('insertIntoInput', e.target.href.replace(/^.*#insert:/, ''));
  }

  loadOffScreen(html, id) {
    if (html.match(/^<a\s/)) return;
    var $html = $(html);
    $html.filter('img').add($html.find('img')).addClass('embed materialboxed');
    $('#' + id).parent().append($html).find('.materialboxed').materialbox();

    $html.filter('img, iframe').each(function() {
      $(this).css('height', '1px').load(function() {
        if (tag.parent.atBottom) window.nextTick(function() { tag.parent.gotoBottom(true) });
        $(this).css('height', 'auto');
        tag.parent.update();
      });
    });
  }

  removeMessage(e) {
    this.dialog.removeMessage(this.msg);
  }

  this.on('mount', function() {
    var c = [];
    if (this.msg.special) c.push('special') && c.push(this.msg.special);
    if (this.msg.highlight) c.push('highlight');
    if (this.msg.type) c.push(this.msg.type);
    c.push(this.dialog.groupedMessage(this.msg) ? 'same' : 'hr');
    $(this.root).addClass(c.join(' '));
  });

  this.on('mount', function() {
    if (this.msg.special) return;
    $('.message', this.root).html(
      this.msg.message.xmlEscape().autoLink({
        target: '_blank',
        after: function(url, id) {
          $.get('/api/embed?url=' + encodeURIComponent(url), function(html, textStatus, xhr) {
            tag.loadOffScreen(html, id);
          });
          return null;
        }
      }).mdToHtml()
    );
  });

  this.on('update', function() {
    if (this.msg.special != 'users') return;
    var users = this.dialog.users()
    this.users = Object.keys(users).sort().map(function(name) { return users[name]; });
  });
  </script>
</dialog-message>
