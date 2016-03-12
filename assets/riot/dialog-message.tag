<dialog-message>
  <span if={msg.type == 'action'}>✧</span>
  <a href={'#insert:' + msg.from} class="title" onclick={insertIntoInput}>{msg.from}</a>
  <div class="message" if={msg.type != 'error'}></div>
  <div class="error" if={msg.type == 'error'}>{msg.message}</div>
  <span class="secondary-content ts tooltipped" title={msg.ts.toLocaleString()}>{timestring(msg.ts)}</span>
  <script>
  if (!opts.msg.message) return;

  var tag = this;
  mixin.time(this);

  this.dialog = opts.dialog;
  this.msg = opts.msg;
  this.user = opts.user;

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

  this.on('mount', function() {
    var c = [this.msg.type || 'normal'];
    if (this.msg.highlight) c.push('highlight');
    c.push(this.dialog.groupedMessage(this.msg) ? 'same-user' : 'changed-user');
    $(this.root).addClass(c.join(' '));
  });

  this.on('mount', function() {
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
  </script>
</dialog-message>
