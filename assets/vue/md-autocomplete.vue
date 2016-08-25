<template>
  <div class="input-field col" :class="cols">
    <input
      :id="id" :placeholder="placeholder" v-model="value"
      @keydown="keydown" @keyup="keyup"
      @focus="hasFocus=true" @blur="hasFocus=false"
      type="text" autocomplete="off" spellcheck="false">
    <label :for="id" :class="{active:labelActive}"><slot></slot></label>
    <div class="autocomplete" :class="filteredOptions.length ? '' : 'hidden'">
      <ul>
        <li :class="optionClass(o, $index)" v-for="o in filteredOptions" v-tooltip="o.title">
          <a href="#{{o.value}}" class="truncate" @click.prevent="select(o)">{{o.text || o.value}}</a>
        </li>
      </ul>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["cols", "id", "placeholder", "options", "value"],
  computed: {
    filteredOptions: function() {
      var re = new RegExp(this.value, 'i');
      return this.options.filter(function(o) { return (o.text || o.value).match(re); });
    },
    labelActive: function() {
      return this.value || this.placeholder || this.hasFocus;
    }
  },
  data: function() {
    return {hasFocus: false, selected: -1};
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
  },
  ready: function() {
    if (!this.id) this.id = Materialize.guid();
    if (!this.cols) this.cols = "s12";
  }
};
</script>
