'use strict';

(() => {
  const vscode = acquireVsCodeApi();
  const content = document.getElementById('content');

  // Lets VS Code restore the preview after a reload.
  vscode.setState({ uri: document.currentScript.dataset.uri });

  // Replaces the content in place, so the scroll position stays where it was.
  window.addEventListener('message', ({ data }) => {
    document.getElementById('raindown-error')?.remove();

    if (data.error === undefined) {
      content.innerHTML = data.html;
      return;
    }

    const error = document.createElement('pre');
    error.id = 'raindown-error';
    error.textContent = data.error;
    document.body.prepend(error);
  });

  // The <base> tag points relative links at the document's folder, so anchors are scrolled to here and
  // relative files are opened by the extension.
  document.addEventListener('click', (event) => {
    const link = event.target.closest('a[href]');
    const href = link?.getAttribute('href');
    if (!href || /^[a-z][\w+.-]*:/i.test(href)) return;

    event.preventDefault();

    if (href.startsWith('#')) {
      document.getElementById(decodeURIComponent(href.slice(1)))?.scrollIntoView();
    } else {
      vscode.postMessage({ href });
    }
  });
})();
