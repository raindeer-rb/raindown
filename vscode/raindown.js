'use strict';

const childProcess = require('child_process');
const vscode = require('vscode');

const TIMEOUT = 10000;
const MAX_BUFFER = 32 * 1024 * 1024;

function command() {
  return vscode.workspace.getConfiguration('raindown').get('path') || 'raindown';
}

// "raindown FILE --stdin" renders the Markdown it's given without touching FILE, which only decides whether
// bare directives are allowed. --bare allows them for any document in the Raindown language, saved or not.
function args(filePath, { bare }) {
  return [filePath, '--stdin', ...(bare ? ['--bare'] : [])];
}

const OPTIONS = { timeout: TIMEOUT, maxBuffer: MAX_BUFFER };

function errorMessage(error, stderr) {
  if (error.code === 'ENOENT') {
    return `Couldn't run "${command()}". Install the raindown gem or a standalone binary, or set "raindown.path".`;
  }

  return (stderr && stderr.trim()) || error.message;
}

// For the Markdown preview, whose plugins render synchronously.
function renderSync(markdown, filePath, { bare = false } = {}) {
  try {
    return childProcess.execFileSync(command(), args(filePath, { bare }), {
      ...OPTIONS, input: markdown, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe']
    });
  } catch (error) {
    throw new Error(errorMessage(error, error.stderr && error.stderr.toString()));
  }
}

function render(markdown, filePath, { bare = false } = {}) {
  return new Promise((resolve, reject) => {
    const child = childProcess.execFile(command(), args(filePath, { bare }), OPTIONS, (error, stdout, stderr) => {
      error ? reject(new Error(errorMessage(error, stderr))) : resolve(stdout);
    });

    child.stdin.on('error', () => {}); // The exit callback reports why raindown stopped reading.
    child.stdin.end(markdown);
  });
}

module.exports = { render, renderSync };
