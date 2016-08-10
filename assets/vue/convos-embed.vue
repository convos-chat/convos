<template>
  <div class="convos-embed is-sidebar">
    <header><convos-menu :user="user"></convos-menu></header>
    <div class="embed-content">{{{content()}}}</div>
  </div>
</template>
<script>
module.exports = {
  methods: {
    content: function() {
      var el = this.$root.embedViewerElement; // this is one big ugly hack
      if (!el) return 'Nothing to embed.';
      return el.innerHTML;
    }
  }
};
</script>
