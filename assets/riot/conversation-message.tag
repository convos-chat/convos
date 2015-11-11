<conversation-message>
  <div class="message" name="message" title={timestring(ts)}></div>
  <script>
  mixin.time(this);

  this.on('mount', function() {
    $('div', this.root).html(opts.message.autoLink({
      target: '_blank',
      after: function(url) {
        if (/\.(gif|png|jpe?g)$/i.test(url)) {
          return '<img class="embed materialboxed" src="' + url + '">';
        }
        else {
          return null;
        }
      }
    }));
    $('.materialboxed', this.root).materialbox();
    $('img, iframe', this.root).load(function() {
      if (window.isScrolledToBottom) window.scrollToBottom();
    });
  });
  </script>
</conversation-message>
