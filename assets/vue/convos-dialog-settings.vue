<template>
  <div class="convos-dialog-settings is-sidebar">
    <header><convos-header-links :user="user"></convos-header-links></header>
    <div class="content" v-if="!dialog">
      <div class="row">
        <div class="col s12">
          <h5>About Convos</h5>
          <convos-resources></convos-resources>
        </div>
      </div>
    </div>
    <convos-dialog-information :dialog="dialog" v-if="dialog && dialog.dialog_id"></convos-dialog-information>
    <convos-connection-editor :connection="dialog.connection()" :user="user" v-if="dialog && !dialog.dialog_id"></convos-connection-editor>
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
