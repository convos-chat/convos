<conversation-message>
  <div class="message" name="message" title={timestring(ts)}></div>
  <script>
  mixin.time(this);

  this.on('mount', function() {
    $('div', this.root).html(opts.message.autoLink({
      target: '_blank',
      after: function(url, id) {
        if (/\.(gif|png|jpe?g)$/i.test(url)) {
          return '<img class="embed materialboxed" src="' + url + '">';
        }
        else {
          $.get('/api/embed?url=' + encodeURIComponent(url), function(html, textStatus, xhr) {
            if (html.match(/^<a\s/)) return;
            window.loadOffScreen($('#' + id).after(html).parent());
          });
          return null;
        }
      }
    }));
    $('.materialboxed', this.root).materialbox();
    window.loadOffScreen($(this.root));
  });
  </script>
</conversation-message>
