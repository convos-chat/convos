(function() {
  var spacing = 2;

  // <a v-dropdown.literal="my_dropdown">...</a>
  // <ul class="dropdown-content" v-el:my_dropdown>...</ul>
  Vue.directive("dropdown", {
    bind: function() {
      var vm = this.vm;

      this.el.addEventListener("click", function(e) {
        e.preventDefault();

        var self = this;
        var target = vm.$els[this.dropdownId];
        var p = $(this).offsetParent().get(0) || this.ownerDocument || document.documentElement;
        var p_offset = p.getBoundingClientRect();
        var offset = this.getBoundingClientRect();

        var hideDropdown = function(e) {
          if ($(e.target).closest(self).length) return;
          $(document).unbind("click touchstart", hideDropdown);
          target.style.display = "none";
        };

        offset = {left: offset.left - p_offset.left, top: offset.top - p_offset.top};
        target.style.visibility = "hidden";
        target.style.display = "block";
        target.style.left = offset.left + "px";
        target.style.top = offset.top + "px";
        target.style.whiteSpace = "nowrap";

        if (p.offsetWidth < offset.left + target.offsetWidth) {
          target.style.left = (p.offsetWidth - target.offsetWidth) + "px";
        }

        target.style.visibility = "visible";
        $(target).animate({opacity: 1}, {duration: 300, easing: "easeOutSine"})
        $(document).bind("click touchstart", hideDropdown);
      });
    },
    update: function(v) {
      this.el.href = "#" + v.replace(/_dropdown$/, "");
      this.el.dropdownId = v;
    }
  });
})();
