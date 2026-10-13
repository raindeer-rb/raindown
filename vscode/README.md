# Raindown for VS Code

Highlighting and live preview for [Raindown](https://github.com/raindeer-rb/raindown) directives.

| | Markdown (`.md`) | Raindown (`.rd`, `.raindown`) |
| --- | --- | --- |
| Highlights `<{ :toc }>` directives | ✓ | ✓ |
| Highlights bare directives like `:toc` | | ✓ |
| Preview | The built-in Markdown preview, rendered by raindown when the file has `<{ }>` syntax | **Raindown: Open Preview** (`Cmd+Shift+V`) or **Open Preview to the Side** (`Cmd+K V`) |

Directives in code and comments aren't highlighted, matching what Raindown renders.

The previews render the unsaved text with `raindown FILE --stdin`, so they update as you type and never change the file. The table of contents and table alignment are written to the file by `raindown FILE`, and endpoints only run there with `-x`.

## Requirements

The `raindown` executable, from the [cross-platform binary](https://github.com/raindeer-rb/raindown/releases) or via `gem install raindown`. If `raindown` isn't on your PATH then set `raindown.path` to the full path of the executable.

## Settings

| Setting                    | Default    |                                                             |
|--------------------------- | ---------- | ----------------------------------------------------------- |
| `raindown.path`            | `raindown` | The file path to the raindown executable                    |
| `raindown.markdownPreview` | `true`     | Highlight Raindown syntax in the built-in Markdown preview. |

Note: Turn off `markdownPreview` to keep the plain preview, which also keeps its scroll sync.

## Development

The extension is plain JavaScript with no dependencies or build step. Open this folder in VS Code and press F5 to start a window with the extension loaded, opened on `../examples`.

To package it, run `npx @vscode/vsce package`, then install it with `code --install-extension raindown-0.1.0.vsix`.
