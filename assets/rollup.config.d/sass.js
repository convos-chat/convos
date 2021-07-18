const sass = require('sass');
const scss = require('rollup-plugin-scss');

module.exports = function(config, {isDev}) {
  const outputStyle = isDev ? null : 'compressed';
  config.plugins.push(scss({outputStyle, sass, sourceMap: true, watch: './assets/sass'}));
};
