<template>
  <div class="convos-embed">
    <div class="actions">
      <a href="#chat"><i class="material-icons">close</i></a>
    </div>
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
