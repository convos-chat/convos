<template>
  <div class="input-field col" :class="cols">
    <textarea lazy v-model="value" class="validate materialize-textarea"
      :id="id" v-el:input :name="name"
      :readonly="readonly"
      :disabled="disabled" :required="required"
      @focus="hasFocus=true" @blur="hasFocus=false">
    </textarea>
    <label :for="id" :class="{active:labelActive}"><slot></slot></label>
  </div>
</template>
<script>
module.exports = {
  props: ["cols", "disabled", "focus", "id", "name", "readonly", "required", "value"],
  data: function() {
    return {hasFocus: false, mdValue: ""};
  },
  computed: {
    labelActive: function() {
      return this.value || this.hasFocus;
    }
  },
  ready: function() {
    if (!this.cols) this.cols = "s12";
    if (!this.id) this.id = Materialize.guid();
    if (!this.name) this.name = this.id;
    if (this.focus) this.$els.input.focusOnDesktop();
  }
};
</script>
