riot.tag2('dialog-message', '<div class="message" name="message" title="{timestring(ts)}"></div>', '', '', function(opts) {
  mixin.time(this);

  this.loadOffScreen = function(html, textStatus, xhr) {
    if (html.match(/^<a\s/)) return;
    var tag = this;
    var $html = $(html);
    $html.filter('img').add($html.find('img')).addClass('embed materialboxed');
    $('#' + id).parent().append($html).find('.materialboxed').materialbox();

    $html.find('img, iframe').each(function() {
      $(this).css('height', '1px').load(function() {

        $(this).css('height', 'auto');
        tag.parent.update();
      });
    });
  }.bind(this)

  this.on('mount', function() {
    $('div', this.root).html(opts.message.autoLink({
      target: '_blank',
      after: function(url, id) {
        $.get('/api/embed?url=' + encodeURIComponent(url), this.loadOffScreen);
        return null;
      }
    }));
  });
}, '{ }');
