<template>
  <div class="md-autocomplete">
    <input
      :id="id"
      v-model="value"
      @keydown="keydown"
      @keyup="keyup"
      type="text" autocomplete="off" spellcheck="false">
    <div class="autocomplete">
      <ul>
        <li :class="optionClass(o, $index)" v-for="o in filteredOptions" :data-hint="o.title">
          <a href="option://{{o.value}}" class="truncate" @click="select(o)">{{o.text || o.value}}</a>
        </li>
      </ul>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["id", "value", "options"],
  computed: {
    filteredOptions: function() {
      var re = new RegExp(this.value, 'i');
      return this.options.filter(function(o) { return (o.text || o.value).match(re); });
    }
  },
  data: function() {
    return {selected: -1};
  },
  methods: {
    keydown: function(e) {
      switch (e.keyCode) {
        case 38: // up
        case 40: // down
          e.preventDefault();
      }
    },
    keyup: function(e) {
      switch (e.keyCode) {
        case 13: // enter
          if (this.selected >= 0 && this.filteredOptions[this.selected]) {
            this.select(this.filteredOptions[this.selected]);
          }
          else if (this.value.length) {
            this.select({value: this.value});
          }
          break;
        case 38: // up
          if (--this.selected < 0) this.selected = this.filteredOptions.length - 1;
          this.scrollIntoView();
          break;
        case 40: // down
          if (++this.selected >= this.filteredOptions.length) this.selected = 0;
          this.scrollIntoView();
          break;
        default:
          if (this.selected < 0) this.selected = 0;
          if (!this.value) this.selected = -1;
      }
    },
    optionClass: function(o, i) {
      return {active: i == this.selected ? true : false, link: true};
    },
    scrollIntoView: function() {
      var li = this.$el.querySelectorAll("li")[this.selected];
      if (li) this.$el.querySelector(".autocomplete").scrollTop = li.offsetTop;
    },
    select: function(option) {
      this.$emit("select", option);
    }
  }
};
</script>
