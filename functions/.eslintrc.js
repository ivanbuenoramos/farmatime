module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    'ecmaVersion': 2021,
  },
  extends: [
    'eslint:recommended',
    'google',
  ],
  rules: {
    'max-len': ['warn', { code: 100, ignoreStrings: true }],
    'require-jsdoc': 'off',
    'object-curly-spacing': ['error', 'always'],
  },
  overrides: [
    {
      files: ['**/*.spec.*'],
      env: {
        mocha: true,
      },
      rules: {
        // mocha usa `this.timeout(...)` en los hooks; los specs llevan tablas largas.
        'no-invalid-this': 'off',
        'max-len': 'off',
      },
    },
  ],
  globals: {},
};
