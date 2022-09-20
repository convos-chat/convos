export default {
  collectCoverage: false,
  collectCoverageFrom: ['<rootDir>/assets/**/*.js'],
  moduleFileExtensions: ['js'],
  testEnvironment: 'jsdom',
  watchman: false,
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
  transform: {
    '^.+\\.js$': 'babel-jest',
  }
};
