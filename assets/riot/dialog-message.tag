<dialog-message>
  <div class="message" if={!msg.special}></div>
  <div class="users" if={msg.special == 'users'}>
    <h5 class="title">Participants</h5>
    <span if={!users.length}>No participants. You need to join the dialog first.</span>
    <a href={'#autocomplete:' + u.name} each={u, i in users}>
      {u.mode}{u.name}{i+1 == users.length ? '.' : ', '}
    </a>
  </div>
  <script>
  var tag = this;

  this.msg = opts.msg;
  this.users = [];

  if (opts.msg.users) {
    Object.keys(opts.msg.users).sort().forEach(function(name) {
      tag.users.push(opts.msg.users[name]);
    });
  }

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
    $('div', this.root).html(
      this.msg.message.autoLink({
        target: '_blank',
        after: function(url, id) {
          $.get('/api/embed?url=' + encodeURIComponent(url), this.loadOffScreen);
          return null;
        }
      })
    );
  });
  </script>
</dialog-message>
