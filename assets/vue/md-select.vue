<template>
  <div class="select-wrapper">
    <span class="caret">&#9660;</span>
    <input :value="textValue" :data-activates="guid" :disabled="disabled" readonly="true" class="select-dropdown" type="text">
    <ul class="dropdown-content select-dropdown" :id="guid">
      <slot></slot>
    </ul>
    <select v-el:field :id="id" :name="name" :placeholder="placeholder">
      <option :value="opt.value" :selected="opt.selected" v-for="opt in options">{{opt.content}}</option>
    </select>
  </div>
</template>
<script>
module.exports = {
  props: ["id", "name", "value"],
  data: function() {
    return {active: false, guid: Materialize.guid(), textValue: "", options: []};
  },
  events: {
    'option::added': function(opt) {
      if (opt.selected) {
        this.$children.forEach(function(o) { if (o != opt) o.selected = false; });
        this.setValue(opt);
      }
      else if(!this.$children.filter(function(o) { return o.selected }).length) {
        this.setValue(this.$children[0]);
      }
      this.options.push({selected: opt.selected, value: opt.value});
    },
    'option::removed': function(opt) {
      var next;
      for (i = 0; i < this.$children.length; i++) {
        var o = this.$children[i];
        if (o == opt) continue;
        if (!next) next = o;
        if (o.selected) next = o;
      }
      this.options = this.options.filter(function(o) { return o.value != opt.value; });
      if (next) this.setValue(next);
    },
    'option::selected': function(opt) {
      if (opt.value == this.value) return;
      this.$children.forEach(function(o) { if (o != opt) o.selected = false; });
      this.options.forEach(function(o) { o.selected = opt.value == o.value; });
      this.setValue(opt);
    }
  },
  methods: {
    setValue: function(opt) {
      this.value = opt ? opt.value : "";
      this.textValue = opt ? opt.text() || opt.value : "";
      this.allowChangeEvent = true;
      this.$nextTick(function() {
        if (this.allowChangeEvent) this.$emit('change');
        this.allowChangeEvent = false; // avoid duplicates
      });
      return this; // allow chaining
    }
  },
  watch: {
    value: function () {
      this.$children.forEach(function(o) { o.selected = o.value == this.value; }.bind(this));
      this.options.forEach(function(o) { o.selected = o.value == this.value; }.bind(this));
    }
  },
  ready: function() {
    this.$nextTick(function() {
      $('input:first', this.$el).dropdown({'hover': false, 'closeOnClick': false});
    });
  }
};
</script>
