<template>
  <a :href="d.href()" @click.prevent="setCurrentDialog(d)" :data-hint="d.frozen" :class="dialogClass(d, i)" v-for="(i, d) in user.dialogs">
    <i class="material-icons">{{d.icon()}}</i> <span class="name">{{d.name}}</span>
    <span class="on" v-if="d.connection">{{d.connection.protocol}}-{{d.connection.name}}</span>
    <span class="on" v-else>convos-local</span>
  </a>
  <a href="#create-dialog">
    <i class="material-icons">add</i> Join dialog...
  </a>
  <div class="hr"><hr></div>
  <a href="#connection/{{c.protocol}}-{{c.name}}" :class="connectionClass(c)" v-for="c in user.connections">
    <i class="material-icons">device_hub</i> {{c.protocol}}-{{c.name}}
    <span class="on">{{c.humanState()}}</span>
  </a>
  <a href="#connection">
    <i class="material-icons">add</i> Add connection...
  </a>
</template>
<script>
module.exports = {
  props:   ["user"],
  methods: {
    connectionClass: function(c) {
      return {
        frozen: c.state == 'connected' ? false : true
      };
    },
    dialogClass: function(d, i) {
      if (!i) this.$nextTick(this.overrideHints);
      return {
        active: d.active(),
        frozen: d.frozen
      };
    },
    setCurrentDialog: function(dialog) {
      this.user.dialogs.forEach(function(d) {
        d.active(dialog == d ? true : false);
      });
    }
  }
};
</script>
