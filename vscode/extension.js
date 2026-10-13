'use strict';

const vscode = require('vscode');
const { plugin } = require('./markdown_it');
const { Preview, VIEW_TYPE } = require('./preview');

function activate(context) {
  const show = (column) => (uri) => {
    const editor = vscode.window.activeTextEditor;
    const target = uri instanceof vscode.Uri ? uri : editor?.document.uri;
    if (!target) return;

    vscode.workspace.openTextDocument(target).then((document) => Preview.show(context, document, column()));
  };

  context.subscriptions.push(
    vscode.commands.registerCommand('raindown.showPreview', show(() => vscode.ViewColumn.Active)),
    vscode.commands.registerCommand('raindown.showPreviewToSide', show(() => vscode.ViewColumn.Beside)),
    vscode.window.registerWebviewPanelSerializer(VIEW_TYPE, {
      deserializeWebviewPanel: (panel, state) => Preview.revive(context, panel, state || {})
    }),
    // The built-in preview caches what it rendered, so it refreshes when the setting is toggled.
    vscode.workspace.onDidChangeConfiguration((event) => {
      if (event.affectsConfiguration('raindown')) vscode.commands.executeCommand('markdown.preview.refresh');
    })
  );

  // The built-in Markdown preview calls this to add the markdown-it plugin.
  return { extendMarkdownIt: plugin };
}

function deactivate() {}

module.exports = { activate, deactivate };
