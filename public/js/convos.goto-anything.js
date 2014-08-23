;(function($) {
  window.convos = window.convos || {}

  var addGoto = function($li, $g) {
    var href = $li.find('a').attr('href');
    if (!href || location.href.match(new RegExp(href + '$'))) return;
    $li.find('a').focus(function() { $g.find('a.active').removeClass('active'); });
    $li.addClass('dynamic').get(0).filter_by = $.trim($li.text().toLowerCase());
    $g.find('li.add-dynamic-before-this').before($li);
  };

  $(document).ready(function() {
    var $g = $('form.conversations');

    if (navigator.is_touch_device) $g.find('input').hide();

    $g.find('li').each(function() {
      this.filter_by = $.trim($(this).find('a').text().toLowerCase());
    });

    $g.find('input').on('focus', function() {
      $g.find('a.active').removeClass('active');
      $g.find('a:first').addClass('active');
    }).on('keyup', function(e) { // filter conversation list
      var v = this.value.toLowerCase();
      var channel = convos.isChannel(v);
      var exact;

      $g.find('ul li').each(function(i) {
        if (this.filter_by) this.style.display = this.filter_by.indexOf(v) == -1 ? 'none' : 'block';
        if (!exact) exact = v == this.filter_by;
      });

      $g.find('ul li a').removeClass('active').filter(':visible:first').addClass('active');
      $g.find('li.create')[v.length && !exact ? 'show' : 'hide']();
      $g.find('li.create').find('.description').text((channel ? 'Join channel "' : 'Chat with "') + v + '" on...');
      $g.find('li.create').find('button').text(channel ? 'Join' : 'Chat');
    });

    $g.on('submit', function(e) { // change or create conversation
      e.preventDefault();
      var $input = $(this).find('input');
      var $first = $(this).find('a:visible:first').click();
      var command = [convos.isChannel($input.val()) ? '/join' : '/query', $input.val()].join(' ');
      if ($first.length == 0) convos.send(command, { 'data-network': $g.find('li.create select').val() });
      $input.val('').keyup();
    });

    $g.on('show', function(e) {
      var i = 0;
      var networks = [];
      $g.find('li.dynamic').remove();
      $('nav ul.conversations li').slice(1).map(function() { // slice(1) == skip convos icon
        var $li = $(this).clone();
        var network = $li.find('a').attr('data-network');
        networks.push(network);
        $li.find('a span').html($li.find('a span').text() + '<small> on ' + network + '</small>');
        addGoto($li, $g);
      });
      $('form.sidebar li.nick').each(function() {
        var $li = $(this).clone();
        $li.find('a').html($li.find('a').text() + '<small> in ' + convos.current.target + '</small>');
        addGoto($li, $g);
      });
      $.each(networks.unique(), function() { addGoto($('<li><a href="' + $.url_for(this) + '">' + this + ' <small>server</small></a></li>'), $g); });
    });

    $g.find('li.create select').selectize({ create: false, openOnFocus: false });
  });
})(jQuery);
