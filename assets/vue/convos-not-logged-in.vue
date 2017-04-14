<template>
  <div :class="'convos-' + screen">
    <div class="row not-logged-in-wrapper">
      <form @submit.prevent="submit" class="col s12 m6 offset-m3">
        <div class="row">
          <div class="col s12">
            <h1>Convos</h1>
            <p><i>- Collaboration done right.</i></p>
          </div>
        </div>
        <slot></slot>
        <div class="row">
          <div class="col s12 about">
            <template v-if="settings.organization_url != 'http://convos.by'">
              <a :href="settings.organization_url">{{settings.organization_name}}</a> -
            </template>
            <a href="http://convos.by">About</a> -
            <a href="http://convos.by/doc">Documentation</a> -
            <a href="http://convos.by/blog">Blog</a> -
            <a href="#recover" @click.prevent="this.user.currentPage = 'convos-recover'">Forgot password?</a>
          </div>
        </div>
      </form>
    </div>
  </div>
</template>
<script>
module.exports = {
  props: ["screen", "user"],
  methods: {
    submit: function(e) {
      this.$emit("submit", e)
    },
  }
};
</script>
