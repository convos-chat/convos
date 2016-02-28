<dialog-message>
  <div class="message" if={!msg.special}></div>
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
    <a href={'#autocomplete:' + u.name} each={u, i in users}>
      {u.mode}{u.name}{i+1 == users.length ? '.' : ', '}
    </a>
  </div>
  <script>
  var tag = this;

  this.dialog = opts.dialog;
  this.msg = opts.msg;
  this.users = [];

  loadOffScreen(html, textStatus, xhr) {
    if (html.match(/^<a\s/)) return;
    var $html = $(html);
    $html.filter('img').add($html.find('img')).addClass('embed materialboxed');
    $('#' + id).parent().append($html).find('.materialboxed').materialbox();

    $html.find('img, iframe').each(function() {
      $(this).css('height', '1px').load(function() {
        //if (window.isScrolledToBottom) setTimeout(function() { window.scrollToBottom() }, 2);
        $(this).css('height', 'auto');
        tag.parent.update();
      });
    });
  }

  this.on('mount', function() {
    if (this.msg.special) return;
    $('.message', this.root).html(
      this.msg.message.xmlEscape().autoLink({
        target: '_blank',
        after: function(url, id) {
          $.get('/api/embed?url=' + encodeURIComponent(url), this.loadOffScreen);
          return null;
        }
      })
    );
  });

  this.on('update', function() {
    if (this.msg.special != 'users') return;
    var users = this.dialog.users()
    this.users = Object.keys(users).sort().map(function(name) { return users[name]; });
  });
  </script>
</dialog-message>
