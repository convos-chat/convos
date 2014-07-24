;(function($) {
  window.convos = window.convos || {}

  convos.conversations = {
    add: function($e) {
      var url = $.url_for($e.attr('data-network'), encodeURIComponent($e.attr('data-target')));
      $.pjax({ url: url, container: 'div.messages', fragment: 'div.messages'});
    },
    remove: function($e) {
      var url = $.url_for($e.attr('data-network'), encodeURIComponent($e.attr('data-target')));
      $('nav ul.conversations a').slice(1).each(function() {
        if(this.href.indexOf(url) >= 0) return;
        $(this).click();
        return false;
      });
    }
  };
})(jQuery);
