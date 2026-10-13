'use strict';

const crypto = require('crypto');
const vscode = require('vscode');
const raindown = require('./raindown');

const VIEW_TYPE = 'raindown.preview';
const DELAY = 300;

// A webview that shows a document rendered by raindown, updating as it's edited.
class Preview {
  static previews = new Map();

  static show(context, document, column) {
    const existing = Preview.previews.get(document.uri.toString());
    if (existing) return existing.panel.reveal(column);

    const panel = vscode.window.createWebviewPanel(VIEW_TYPE, title(document), column, webviewOptions(context, document));
    new Preview(context, document, panel);
  }

  // Restores a preview that was open when VS Code last closed.
  static async revive(context, panel, state) {
    try {
      const document = await vscode.workspace.openTextDocument(vscode.Uri.parse(state.uri));
      panel.webview.options = webviewOptions(context, document);
      new Preview(context, document, panel);
    } catch {
      panel.dispose();
    }
  }

  constructor(context, document, panel) {
    this.context = context;
    this.document = document;
    this.panel = panel;
    this.version = 0;

    Preview.previews.set(document.uri.toString(), this);
    panel.webview.html = this.page();

    this.disposables = [
      panel.onDidDispose(() => this.dispose()),
      panel.webview.onDidReceiveMessage((message) => this.open(message.href)),
      vscode.workspace.onDidChangeTextDocument((event) => event.document === document && this.scheduleUpdate()),
      vscode.workspace.onDidChangeConfiguration((event) => event.affectsConfiguration('raindown') && this.update())
    ];

    this.update();
  }

  scheduleUpdate() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.update(), DELAY);
  }

  // Renders can finish out of order, so only the latest one is shown.
  async update() {
    const version = ++this.version;
    const bare = this.document.languageId === 'raindown';
    let message;

    try {
      message = { html: await raindown.render(this.document.getText(), this.document.uri.fsPath, { bare }) };
    } catch (error) {
      message = { error: error.message };
    }

    if (version === this.version) this.panel.webview.postMessage(message);
  }

  // Relative links open in VS Code, beside the document.
  open(href) {
    const [file, fragment] = href.split('#');
    const uri = vscode.Uri.joinPath(this.document.uri, '..', decodeURI(file)).with({ fragment: fragment || '' });

    vscode.commands.executeCommand('vscode.open', uri);
  }

  dispose() {
    clearTimeout(this.timer);
    Preview.previews.delete(this.document.uri.toString());
    this.disposables.forEach((disposable) => disposable.dispose());
  }

  page() {
    const webview = this.panel.webview;
    const nonce = crypto.randomBytes(16).toString('base64');
    const media = (file) => webview.asWebviewUri(vscode.Uri.joinPath(this.context.extensionUri, 'media', file));
    const base = this.document.uri.scheme === 'file' ? `<base href="${webview.asWebviewUri(vscode.Uri.joinPath(this.document.uri, '..'))}/">` : '';

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource} https: data:; style-src ${webview.cspSource} 'unsafe-inline'; font-src ${webview.cspSource}; script-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  ${base}
  <link rel="stylesheet" href="${media('preview.css')}">
</head>
<body>
  <main id="content"></main>
  <script nonce="${nonce}" src="${media('preview.js')}" data-uri="${escapeAttribute(this.document.uri.toString())}"></script>
</body>
</html>`;
  }
}

// The page can load the extension's media, and images from the workspace and beside the document.
function webviewOptions(context, document) {
  const roots = [vscode.Uri.joinPath(context.extensionUri, 'media')];
  roots.push(...(vscode.workspace.workspaceFolders || []).map((folder) => folder.uri));
  if (document.uri.scheme === 'file') roots.push(vscode.Uri.joinPath(document.uri, '..'));

  return { enableScripts: true, localResourceRoots: roots };
}

function title(document) {
  return `Preview ${document.uri.path.split('/').pop()}`;
}

function escapeAttribute(value) {
  return value.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

module.exports = { Preview, VIEW_TYPE };
