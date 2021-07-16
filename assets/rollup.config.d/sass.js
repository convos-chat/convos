const sass = require('sass');
const scss = require('rollup-plugin-scss');

module.exports = function(config) {
  config.plugins.push(scss({sass, sourceMap: true, watch: './assets/sass'}));
};
