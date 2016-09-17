(function($) {
  if (document.location.href.match(/^http:\/\/(www.)?convos.by/)) {
    document.location = document.location.href.replace(/^http:/, "https:");
  }

  $(document).ready(function() {
    $("ul.toc").each(function() {
      var toc = [];
      var h3 = false;
      $(".content").find("h2[id], h3[id]").each(function() {
        var $h = $(this);
        if ($h.is("h3")) {
          if (!h3) toc.push("<ul>");
          h3 = true;
        }
        else if(h3) {
          toc.push("</ul>");
          h3 = false;
        }
        toc.push('<li><a href="#' + this.id + '">' + $(this).text() + '</a></li>');
        $(this).html('<a href="#top">' + $(this).text() + '</a>');
      });
      if (h3) toc.push("</ul>");
      $(this).html(toc.join(""));
    });
  });
})(jQuery);
