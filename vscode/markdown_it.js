'use strict';

const vscode = require('vscode');
const raindown = require('./raindown');

// The preview doesn't say which document it's parsing, and only bare directives depend on the file,
// which Markdown files don't allow, so any .md name renders the same.
const FILE = 'preview.md';

let warned = false;

// Hands Markdown that has <{ }> directives to raindown, and replaces markdown-it's tokens with its HTML.
// Without directives, or if raindown fails, markdown-it renders the document as usual.
function plugin(md) {
  md.core.ruler.push('raindown', (state) => {
    if (!vscode.workspace.getConfiguration('raindown').get('markdownPreview') || !state.src.includes('<{')) return;

    let html;
    try {
      html = raindown.renderSync(state.src, FILE);
    } catch (error) {
      warnOnce(error);
      return;
    }

    const token = new state.Token('html_block', '', 0);
    token.content = html;
    token.block = true;
    token.map = [0, state.src.split('\n').length];
    state.tokens = [token];
  });

  return md;
}

// The preview re-parses as you type, so only the first failure is shown.
function warnOnce(error) {
  if (warned) return;

  warned = true;
  vscode.window.showWarningMessage(`Raindown: ${error.message} Showing the plain Markdown preview.`);
}

module.exports = { plugin };
