(function() {
  var spacing = 4;

  // <a v-tooltip.literal="Some helpful message">...</a>
  Vue.directive("tooltip", {
    bind: function() {
      if (window.isMobile()) return;
      this.el.addEventListener("mouseover", function(e) {
        var tip = document.getElementById("vue_tooltip")
        var offset = this.getBoundingClientRect();
        var css = {};

        // do not want to show empty tooltip
        if (this.vueTooltip.match(/^\s*$/)) return;

        tip.childNodes[0].textContent = this.vueTooltip;
        offset.left = offset.left + window.pageXOffset - this.ownerDocument.clientLeft;
        offset.top = offset.top + window.pageYOffset - this.ownerDocument.clientTop;
        css.right = "auto";
        css.left = offset.left - (tip.offsetWidth - this.offsetWidth) / 2;
        css.top = offset.top - tip.offsetHeight - spacing;

        if (css.left < 0) {
          css.left = spacing;
        }
        else if (css.left + tip.offsetWidth + spacing > window.innerWidth) {
          css.left = "auto";
          css.right = spacing;
        }

        if (css.top < spacing) {
          css.top = this.offsetTop + this.offsetHeight + spacing;
        }

        Object.keys(css).forEach(function(k) {
          if (parseInt(css[k])) css[k] = css[k] + "px";
          tip.style[k] = css[k];
        });

        tip.className = "active";
      });
      this.el.addEventListener("mouseleave", function(e) {
        var tip = document.getElementById("vue_tooltip")
        tip.className = "";
      });
    },
    update: function(v, o) {
      this.el.vueTooltip = typeof v == "undefined" ? "" : v;
      document.getElementById("vue_tooltip").style.left = "-2000px";
    }
  });
})();
