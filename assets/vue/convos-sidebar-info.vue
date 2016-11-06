<template>
  <div class="convos-sidebar-info is-sidebar">
    <header><convos-header-links :user="user"></convos-header-links></header>
    <div class="content" v-if="!dialog">
      <div class="row">
        <div class="col s12">
          <h5>About Convos</h5>
          <convos-resources></convos-resources>
        </div>
      </div>
    </div>
    <convos-dialog-info :dialog="dialog" :user="user" v-if="dialog"></convos-dialog-info>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  computed: {
    dialog: function() {
      return this.user.getActiveDialog();
    }
  }
};
</script>
