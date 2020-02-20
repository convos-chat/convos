module.exports = {
  moduleFileExtensions: ['js'],
  watchman: false,
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
  transform: {
    '^.+\\.js$': 'babel-jest',
  },
  collectCoverage: false,
  collectCoverageFrom: ['<rootDir>/assets/**/*.js']
};
