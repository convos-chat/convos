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
    <convos-dialog-settings :dialog="dialog" :user="user" v-if="dialog && dialog.dialog_id"></convos-dialog-settings>
    <convos-connection-settings :connection="dialog.connection()" :user="user" v-if="dialog && !dialog.dialog_id"></convos-connection-settings>
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
