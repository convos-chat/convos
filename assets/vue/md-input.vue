<template>
  <div class="input-field col" :class="cols">
    <input lazy v-model="value" class="validate" autocomplete="nope"
      :id="id" v-el:input :name="name" :placeholder="placeholder"
      :readonly="readonly"
      :type="type" :disabled="disabled" :required="required"
      @focus="hasFocus=true" @blur="hasFocus=false">
    <label :for="id" :class="{active:labelActive}"><slot></slot></label>
  </div>
</template>
<script>
module.exports = {
  props: ["cols", "disabled", "focus", "id", "name", "placeholder", "readonly", "required", "type", "value"],
  data: function() {
    return {hasFocus: false, mdValue: ""};
  },
  computed: {
    labelActive: function() {
      return this.value || this.placeholder || this.hasFocus;
    }
  },
  ready: function() {
    if (!this.cols) this.cols = "s12";
    if (!this.type) this.type = "text";
    if (!this.id) this.id = Materialize.guid();
    if (!this.name) this.name = this.id;
    if (this.focus) this.$els.input.focusOnDesktop();
  }
};
</script>
