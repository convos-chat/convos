<dialog-message>
  <div class="message" name="message" title={timestring(ts)}></div>
  <script>
  mixin.time(this);

  loadOffScreen(html, textStatus, xhr) {
    if (html.match(/^<a\s/)) return;
    var tag = this;
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
    $('div', this.root).html(opts.message.autoLink({
      target: '_blank',
      after: function(url, id) {
        $.get('/api/embed?url=' + encodeURIComponent(url), this.loadOffScreen);
        return null;
      }
    }));
  });
  </script>
</dialog-message>
