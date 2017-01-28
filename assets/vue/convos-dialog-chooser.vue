<template>
  <div class="input-field col s12">
    <input v-el:input v-model="value" autocomplete="off" class="validate" spellcheck="false" type="text"
      :disabled="disabled" :id="id" debounce="200" placeholder="#channel_name"
      @blur="hasFocus=false" @focus="hasFocus=true" @keydown="keydown" @keyup="keyup">
    <label :for="id" class="active">Dialog name</label>
    <div class="autocomplete" :class="filteredOptions.length ? '' : 'hidden'">
      <a href="#join:{{room.name}}" class="title" :class="optionClass($index)" @click.prevent="select(room)" v-for="room in filteredOptions">
          <span class="badge"><i class="material-icons" v-if="room.n_users">person</i>{{room.n_users || "new"}}</span>
          <h6>{{room.name}}</h6>
          <p>{{topic(room.topic) | markdown}}</p>
      </a>
    </div>
  </div>
</template>
<script>
module.exports = {
  mixins: [Convos.mixin.autocomplete],
  data: function() {
    return {hasFocus: false};
  },
  computed: {
    filteredOptions: function() {
      var options = this.options || [];

      if (this.value) {
        options = [{name: this.value, topic: "Click here to create/join custom dialog"}].concat(options);
        if (options.length == 2) {
          options[0] = options.splice(1, 1, options[0])[0];
        }
        else if (options.length > 1 && options[0].name == options[1].name) {
          options.shift();
        }
      }

      return options;
    }
  },
  methods: {
    topic: function(str) {
      if (!str) return "No topic.";
      if (str.length < 200) return str;
      return str.substr(0, 200).replace(/\S+$/, "") + "...";
    }
  },
  ready: function() {
    this.id = Materialize.guid();
    this.$els.input.focusOnDesktop();
  }
};
</script>
