<template>
  <convos-not-logged-in screen="recover" :user="user">
    <div class="row">
      <md-input :value.sync="email" type="email" id="form_login_email">Your login email</md-input>
    </div>
    <div class="row">
      <div class="col s12">
        Forgot your password? Tell your Convos admin to run the command below,
        and then send you the recovery link:
        <pre class="stylish">$ convos get /user/recover/{{email || 'your-email@example.com'}}</pre>
      </div>
    </div>
    <div class="row">
      <div class="col s12">
        <a :href="'#login" @click.prevent="user.currentPage = 'convos-recover'" class="btn waves-effect waves-light">Login</a>
      </div>
    </div>
  </convos-not-logged-in>
</template>
<script>
module.exports = {
  props: ["user"],
  data: function() {
    return {email: localStorage.getItem("email") || ""};
  }
};
</script>
