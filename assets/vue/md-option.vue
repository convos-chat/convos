<template>
  <li @click="select" class="{{selected ? 'active' : ''}}">
    <span>
      <input :checked="selected" :disabled="disabled" type="checkbox" v-if="$parent.multiple">
      <slot>{{value}}</slot>
    </span>
  </li>
</template>
<script>
module.exports = {
  props: ["disabled", "selected", "value"],
  watch: {
    selected: function(v, o) {
      if (v && !o) this.select();
    }
  },
  methods: {
    text: function() {
      if (!this.$el) return;
      return this.$el.querySelector('span').innerText.trim();
    },
    select: function() {
      if (this.disabled) return;
      this.selected = true;
      this.$parent.$emit('option::selected', this);
    }
  },
  beforeDestroy: function() {
    this.$parent.$emit('option::removed', this);
  },
  ready: function() {
    this.$parent.$emit('option::added', this);
  }
};
</script>
