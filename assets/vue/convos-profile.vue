<template>
  <div class="convos-profile">
    <div class="row">
      <div class="col s12">
        <div class="actions">
          <a href="#chat"><i class="material-icons">close</i></a>
        </div>
        <h5>Edit profile</h5>
      </div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <input id="form_email" readonly="readonly" :value="user.email">
        <!-- label for="form_email">Email (readonly)</label -->
      </div>
    </div>
    <div class="row">
      <div class="input-field col s6">
        <input id="form_password" type="password" class="validate" placeholder="At least six characters">
        <label for="form_password">Password</label>
      </div>
      <div class="input-field col s6">
        <input placeholder="Repeat password" id="form_password_again" type="password" class="validate">
      </div>
    </div>
    <div class="row" v-if="errors.length">
      <div class="col s12"><div class="alert">{{errors[0].message}}</div></div>
    </div>
    <div class="row">
      <div class="input-field col s12">
        <button class="btn waves-effect waves-light" type="submit">Update <i class="material-icons right">save</i></button>
      </div>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["user"],
  data:  function() {
    return {errors: []};
  }
};
</script>
