module.exports = {
  env: {
    test: {
      presets: [
        ['@babel/env', {targets: {node: 10}}],
      ],
    },
  },
};
