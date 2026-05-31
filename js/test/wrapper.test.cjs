const assert = require('node:assert/strict');
const test = require('node:test');

const { resolveBinaryPath, run } = require('../dist/wrapper.js');

test('resolveBinaryPath prefers AMBIENT_BINARY_PATH', () => {
  const binaryPath = resolveBinaryPath({
    env: {
      AMBIENT_BINARY_PATH: '/tmp/custom-ambient',
    },
    platform: 'darwin',
    arch: 'arm64',
  });

  assert.equal(binaryPath, '/tmp/custom-ambient');
});

test('run forwards argv and returns the child exit code', () => {
  let invocation;

  const exitCode = run(['capture', '--config', 'ambient.config.yaml'], {
    env: {
      AMBIENT_BINARY_PATH: '/tmp/custom-ambient',
    },
    platform: 'darwin',
    arch: 'arm64',
    spawn: (command, argv, spawnOptions) => {
      invocation = { command, argv, spawnOptions };

      return {
        error: undefined,
        output: [],
        pid: 42,
        signal: null,
        status: 23,
        stderr: null,
        stdout: null,
      };
    },
  });

  assert.equal(exitCode, 23);
  assert.deepEqual(invocation, {
    command: '/tmp/custom-ambient',
    argv: ['capture', '--config', 'ambient.config.yaml'],
    spawnOptions: { stdio: 'inherit' },
  });
});

test('run reports a missing packaged binary clearly', () => {
  let stderr = '';

  const exitCode = run(['--version'], {
    arch: 'x64',
    dirname: '/tmp/ambientvrt-js/dist',
    env: {},
    platform: 'linux',
    spawn: () => {
      throw new Error('spawn should not be called when the binary is missing');
    },
    stderr: {
      write(chunk) {
        stderr += chunk;
        return true;
      },
    },
  });

  assert.equal(exitCode, 1);
  assert.match(stderr, /The Ambient binary is not installed/);
});

test('run mirrors signal termination when the child exits via a signal', () => {
  let forwardedSignal = null;

  const exitCode = run([], {
    env: {
      AMBIENT_BINARY_PATH: '/tmp/custom-ambient',
    },
    platform: 'darwin',
    arch: 'arm64',
    reemitSignal: (signal) => {
      forwardedSignal = signal;
    },
    signalNumbers: {
      SIGINT: 2,
    },
    spawn: () => ({
      error: undefined,
      output: [],
      pid: 42,
      signal: 'SIGINT',
      status: null,
      stderr: null,
      stdout: null,
    }),
  });

  assert.equal(forwardedSignal, 'SIGINT');
  assert.equal(exitCode, 130);
});
