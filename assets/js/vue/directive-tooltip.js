(function() {
  var spacing = 4;

  // <a v-tooltip.literal="Some helpful message">...</a>
  Vue.directive("tooltip", {
    bind: function() {
      if (window.isMobile) return;
      this.el.addEventListener("mouseover", function(e) {
        var doc = this.ownerDocument || document.documentElement;
        var offset = this.getBoundingClientRect();
        var target = document.getElementById("vue_tooltip")
        var css = {};

        // do not want to show empty tooltip
        if (this.vueTooltip.match(/^\s*$/)) return;

        // the original object is read-only (immutable)
        offset = {left: offset.left, top: offset.top};

        target.childNodes[0].textContent = this.vueTooltip;
        offset.left += (window.pageXOffset || doc.scrollLeft || 0);
        offset.top += (window.pageYOffset || doc.scrollTop || 0);
        css.left = offset.left - (target.offsetWidth - this.offsetWidth) / 2;
        css.top = offset.top - target.offsetHeight - spacing;
        css.right = "auto";

        if (css.left < 0) {
          css.left = spacing;
        }
        else if (css.left + target.offsetWidth + spacing > window.innerWidth) {
          css.left = "auto";
          css.right = spacing;
        }

        if (css.top < (window.pageYOffset || doc.scrollTop || 0)) {
          css.top = this.offsetTop + this.offsetHeight + spacing;
        }

        Object.keys(css).forEach(function(k) {
          if (parseInt(css[k])) css[k] = css[k] + "px";
          target.style[k] = css[k];
        });

        target.className = "active";
      });
      this.el.addEventListener("mouseleave", function(e) {
        document.getElementById("vue_tooltip").className = "";
      });
    },
    update: function(v, o) {
      this.el.vueTooltip = typeof v == "undefined" ? "" : v;
      document.getElementById("vue_tooltip").style.left = "-2000px";
    }
  });
})();
