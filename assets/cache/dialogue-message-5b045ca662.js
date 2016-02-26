riot.tag2('dialogue-message', '<div class="message" name="message" title="{timestring(ts)}"></div>', '', '', function(opts) {
  mixin.time(this);

  this.on('mount', function() {
    $('div', this.root).html(opts.message.autoLink({
      target: '_blank',
      after: function(url, id) {
        $.get('/api/embed?url=' + encodeURIComponent(url), function(html, textStatus, xhr) {
          if (html.match(/^<a\s/)) return;
          var $html = $(html);
          $html.filter('img').add($html.find('img')).addClass('embed materialboxed');
          $('#' + id).parent().append($html).find('.materialboxed').materialbox();
          window.loadOffScreen($html);
        });
        return null;
      }
    }));
    window.loadOffScreen($(this.root));
  });
}, '{ }');
