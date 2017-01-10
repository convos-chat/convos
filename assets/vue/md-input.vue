<template>
  <div class="input-field col" :class="cols">
    <input v-model="value" class="validate" :autocomplete="autocomplete"
      :id="id" v-el:input :name="name" :placeholder="placeholder"
      :readonly="readonly"
      :type="type" :disabled="disabled" :required="required"
      @focus="hasFocus=true" @blur="hasFocus=false">
    <label :for="id" :class="{active:labelActive}"><slot></slot></label>
  </div>
</template>
<script>
module.exports = {
  props: ["autocomplete", "cols", "disabled", "focus", "id", "name", "placeholder", "readonly", "required", "type", "value"],
  data: function() {
    return {hasFocus: false, mdValue: ""};
  },
  computed: {
    labelActive: function() {
      return this.value || this.placeholder || this.hasFocus;
    }
  },
  ready: function() {
    if (typeof this.autocomplete == "undefined" && !this.id) this.autocomplete = "new-password";
    if (!this.cols) this.cols = "s12";
    if (!this.type) this.type = "text";
    if (!this.id) this.id = Materialize.guid();
    if (!this.name) this.name = this.id;
    if (this.focus) this.$els.input.focusOnDesktop();
  }
};
</script>
