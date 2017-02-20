<template>
  <div class="convos-profile">
    <div class="row">
      <div class="col s12">
        <h4>{{user.email}}</h4>
      </div>
    </div>
    <div class="row">
      <md-input :value.sync="password" type="password" placeholder="At least six characters" cols="s6">Password</md-input>
      <md-input :value.sync="passwordAgain" type="password" cols="s6">Repeat password</md-input>
    </div>
    <div class="row">
      <md-input :value.sync="highlightKeywords" placeholder="cats, superheroes, ..." cols="s12">Notification keywords</md-input>
    </div>
    <div class="row">
      <div class="col s12">
        <input v-model="sortDialogsByRead" type="checkbox" class="filled-in" id="form_sort_by">
        <label for="form_sort_by">Sort dialogs by last-read/activity</label>
      </div>
    </div>
    <div class="row">
      <div class="col s12">
        <input v-model="notifications" type="checkbox" class="filled-in" id="form_notifications" :checked="settings.notifications == 'granted'">
        <label for="form_notifications">Enable notifications</label>
      </div>
    </div>
    <div class="row">
      <div class="col s12">
        <input v-model="settings.expandUrls" type="checkbox" class="filled-in" id="form_expand_urls">
        <label for="form_expand_urls">Expand URL to media</label>
      </div>
    </div>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
    <div class="row">
      <div class="col s12">
        <button @click="save" class="btn waves-effect waves-light" type="submit">Save</button>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  data:  function() {
    return {
      errors: [],
      highlightKeywords: "",
      password: "",
      passwordAgain: "",
      notifications: Notification.permission,
      sortDialogsByRead: false
    };
  },
  watch: {
    sortDialogsByRead: function(v, o) {
      this.settings.sortDialogsBy = v ? "lastRead" : "default";
    }
  },
  methods: {
    save: function() {
      var self = this;
      var highlightKeywords = this.highlightKeywords.split(/[,\s]+/).filter(function(k) { return k.length; });

      if (this.password != this.passwordAgain)
        return this.errors = [{message: "Passwords does not match"}];
      if (this.notifications && this.notifications != this.settings.notifications)
        this.enableNotifications(true);
      if (!this.notifications)
        this.enableNotifications(false);

      Convos.api.updateUser({body: {highlight_keywords: highlightKeywords, password: this.password}}, function(err, res) {
        if (!err) this.password = "";
        self.errors = err || [];
      });
    }
  },
  ready: function() {
    this.sortDialogsByRead = this.settings.sortDialogsBy == "lastRead";
    this.highlightKeywords = this.user.highlightKeywords.join(", ");
  }
};
</script>
