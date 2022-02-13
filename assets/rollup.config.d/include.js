const nodePolyfills = require('rollup-plugin-polyfill-node');

module.exports = function(config, opts) {
  config.plugins.push(nodePolyfills());
  require('./sass')(config, opts);
  require('./eslint')(config, opts);
  require('./core')(config, opts);
  require('./js')(config, opts);
  require('./svelte')(config, opts);
};
