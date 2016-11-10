<template>
  <form autocomplete="off" class="convos-connection-editor" @submit.prevent>
    <div class="row">
      <div class="col s12">
        <h4>{{connection ? 'Edit "' + connection.name + '"' : "Add connection"}}</h4>
        <p>
          <template v-if="!user.connections.length">
            You need to add a connection before you can have a dialog.
          </template>
          <template v-if="user.connections.length">
            Click on the "Advanced" button for more settings. In most cases
            they are not requried to start chatting.
          </template>
          <template v-if="!user.connections.length && settings.default_server">
            We have filled in example values, but you can change them if you like.
            In most cases, you can just hit "Create" in the bottom to get started.
          </template>
        </p>
      </div>
    </div>
    <div class="row">
      <md-input :value.sync="server" focus="" :readonly="settings.forced_irc_server" cols="s8 m9">Server</md-input>
      <md-select :value.sync="tls" label="Secure connection" cols="s4 m3">
        <md-option :value="null" :selected="tls == null">Autodetect</md-option>
        <md-option value="0" :selected="tls == 0">No</md-option>
        <md-option value="1" :selected="tls == 1">Yes</md-option>
      </md-select>
    </div>
    <div class="row">
      <md-input :value.sync="nick" placeholder="A nick can be generated for you">Nick</md-input>
    </div>
    <template v-if="advanced">
      <div class="row">
        <md-input :value.sync="username" cols="s6">Username</md-input>
        <md-input :value.sync="password" cols="s6" type="password">Password</md-input>
      </div>
      <div class="row">
        <md-textarea :value.sync="onConnectCommands">On Connect Commands (one per line)</md-textarea>
      </div>
    </template>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
    <div class="row">
      <div class="col s12">
        <a v-link.literal="#" class="btn waves-effect waves-light" v-if="!user.connections.length || !user.dialogs.length">
          <i class="material-icons left">navigate_before</i>Back
        </a>
        <button @click="saveConnection" class="btn waves-effect waves-light">
          {{connection && !deleted ? 'Update' : 'Create'}} <i class="material-icons right">save</i>
        </button>
        <button @click.prevent="toggleAdvanced()" class="btn waves-effect waves-light">
          Advanced <i class="material-icons right">{{advanced ? "close" : "settings"}}</i>
        </button>
        <a href="#delete" @click.prevent="removeConnection" class="btn-delete" v-if="connection">
          <i class="material-icons">delete</i>
        </a>
        <span v-if="connection && connection.state == 'disconnected'">{{connection.message || 'Click "update" to connect.'}}</span>
      </div>
    </div>
  </form>
</template>
<script>
module.exports = {
  mixins: [Convos.mixin.connectionEditor],
  data: function() {
    return {
      advanced: false,
      onConnectCommands: "",
      connection: null,
      deleted: false,
      errors: [],
      password: "",
      nick: "",
      server: "",
      tls: null,
      username: ""
    };
  },
  methods: {
    toggleAdvanced: function(e) {
      this.advanced = !this.advanced;
      if (this.advanced) {
        var $main = $(this.$el).closest("main");
        this.$nextTick(function() {
          $main.animate({scrollTop: $main.height()}, "slow");
        });
      }
    }
  }
};
</script>
