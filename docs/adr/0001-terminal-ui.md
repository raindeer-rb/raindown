# 1. A terminal UI on a document model, drawn with curses

- Status: Accepted
- Date: 2026-10-26
- Note: the TUI's files, classes and terms have changed since this was written. [ADR 2](0002-screen-buffer.md) lists the current ones: panes, views, renderers and `Layout`.

## Context

Raindown watches files and writes back to them: tables of contents, file lists, charts, endpoint responses and custom nodes' Markdown. All of that happens on save, so there's no way to see a file's structure, look at what a directive wrote without scrolling past it, or run one endpoint, short of editing the file.

We want a terminal UI that works as a navigator and controller:

- Browse a project's Markdown files.
- Show the open file's headings and directives as an outline.
- Fold away and show again what each directive wrote back.
- Run an endpoint with a key or a click.
- Open the editor at a line.

The TUI doesn't edit text itself for now. Your editor does that.

Three things were missing for that:

1. **A model of the file.** Headings came from the TOC node, which renders the whole document to HTML and reads the headings back out. Nothing knew where directives were, or which lines they wrote.
2. **Operations that a UI can call.** Writing back was all or nothing (`Rewriter.update`), and endpoints only ran when their response was empty and `:x` or `-x` was given.
3. **A way to draw it.** This was the main decision.

## Decision

### 1. `Document` reads the file's structure from its source

`Raindown::Document` (`lib/raindown/document.rb`) parses a file without rendering it:

- `#headings` gives each heading's level, its source text (like `Notes for {name}`, before variables render) and its line, from Commonmarker's parse tree.
- `#directives` gives each content directive: a node such as `toc:`, `files:`, `chart:` or a project's own, or an `endpoint:`. Each has its name, its args text, its first and last line, and `output`, the range of lines Raindown writes back. For an endpoint that means the response and its fetched date, not the curl snippet, which the author wrote. `output` is nil when nothing has been written yet. `writes` is false for self-closing directives like `<{ :toc }>`, which only render.
- `#outline` lists headings and directives together, in line order.

Node blocks are found with `NodeBlocks.spans`, which now finds a block without creating its node. Rendering uses the same code to find blocks, so the document model and the renderer can't disagree. As when rendering, a project's own node is only a directive once its `.raindown` folder is loaded. Bare directives are read in `.rd` and `.raindown` files, as when rendering.

**Template directives (`if:`, `for:`, `list:`, variables) are left out.** They only change how a file renders and write nothing back, and bare ones get their end tags inserted only when rendering, so their line numbers would shift. They can be added if the navigator needs them.

**Headings in a component's or node's HTML are left out.** Only headings in the source are listed, including ones a directive wrote back into the file, so every heading has a line to open the editor at. The TOC node keeps reading rendered HTML, since it lists every heading on the page.

### 2. `Actions` are the operations a UI calls

`Raindown::Actions` (`lib/raindown/actions.rb`) holds what a tool can do to a file, without knowing how it's drawn:

- `write_back(path)`: the same as a save while watching.
- `execute(path, directive)`: runs one endpoint and replaces its response, even when it has one. It works through a new `only:` option on `EndpointRunner`, which raises curl's error for the caller to show instead of printing it.
- `edit_command(path, line:)`: the command that opens `$VISUAL` or `$EDITOR` at a line, like `vim +12 notes.md`, `hx notes.md:12` or `code --wait -g notes.md:12`.

The VS Code extension could call the same actions later, for example as an Execute link above each endpoint.

### 3. The TUI is plain Ruby, with curses only at the edge

`raindown tui [PATH]` starts it. The layers are:

| Layer                                                                                                                                                                                               | Files                                                                                             | Knows about the terminal? |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------- |
| `Navigator`: focus, events, and the effect of each one. Its `Commands` run actions and set the status. `FileTree` and `Outline` produce each pane's rows. `Pane` holds a cursor and scroll position | `lib/raindown/tui/navigator.rb`, `commands.rb`, `file_tree.rb`, `outline.rb`, `pane.rb`, `row.rb` | No                        |
| `Layout`: the screen as lines of styled segments, each line exactly the terminal's width, where a segment with an event is clickable                                                                | `lib/raindown/tui/layout.rb`                                                                      | No                        |
| `Screen`, `Input`, `Styles`: paint the segments with curses, and turn keys and clicks into events                                                                                                   | `lib/raindown/tui/screen.rb`, `input.rb`, `styles.rb`                                             | Yes                       |

`Navigator#handle(event)` returns what the screen does next:
- `nil`: draw again.
- `:quit`: stop.
- `[:run, command]`: leave the screen to run a command such as the editor, then call `ran`, which writes back.
- `[:wait, message, task]`: show the message while a slow task runs, like an endpoint request.

**Each project's nodes load in a worker process of their own, as when watching.** A project's nodes are Ruby classes, so two projects loaded into one process would merge their nodes of the same name, and one project's nodes would leak into another's files. The terminal UI's process loads no project's nodes:
- **Projects:** `Workers` keeps a forked `Worker` for the folder's project and for each project inside it.
- **Requests:** each file's requests go to the worker of its nearest project. A worker runs a `Project`, which answers four requests: a file's outline, the project's charts, writing back a file, and running an endpoint.
- **Pipes:** requests and answers go through two pipes as Marshal data, and answers are plain data, like a `Document::Directive` or a chart's lines.
- **Reload:** `r` restarts the workers, which loads their nodes again.
- **Without `fork`:** on Windows, the workers answer in the terminal UI's process, and projects' nodes share it again.

Everything above the screen layer has specs that need no terminal. The file is read again when its mtime changes, checked every 500ms while no key is pressed. So saving in an editor updates the outline.

**The TUI watches its folder as `raindown` does,** so it replaces running `raindown` in another terminal. `Saves` listens to the folder with Listen, leaving out the same folders as the watcher (`Supervisor::IGNORE`), and queues each path saved, added or removed, as Listen calls back in a thread of its own. The Navigator takes them on its next tick, in the screen's thread, and writes back each saved Markdown file through its project's worker, saying "Updated" in the status line only when it changed, as the watcher prints only then. A change to a project's nodes reloads the workers, like the watcher restarting the project, and added or removed files are listed again. The write-back saves the file again, which changes nothing, so it ends there, as when watching. Specs stand a plain object in for `Saves`, so they need no Listen.

**We draw with curses (the `curses` gem, a binding to ncurses).** It is a required dependency in the gemspec (`~> 1.7`), so `raindown tui` works wherever Raindown is installed, and it's in every standalone binary. It's only loaded when `raindown tui` starts, so watching and `--html` start no slower. Without a terminal, `raindown tui` stops with "raindown tui needs a terminal" instead of ncurses' "Error opening terminal".

### Options considered

Measured on an Intel Mac (x86_64-darwin) with Ruby 4.0.3, in October 2026.

|                        | curses                                                                                       | ratatui_ruby                                                 | Charm (bubbletea, lipgloss, bubblezone)                                       | tty-cursor, tty-reader, tty-screen                     |
| ---------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------- | ------------------------------------------------------ |
| Native code            | C, against the system's ncurses                                                              | Rust                                                         | Go, as C archives                                                             | None                                                   |
| Installing on this Mac | Built in seconds                                                                             | Needs Rust: no build for x86_64-darwin                       | Precompiled                                                                   | Pure Ruby                                              |
| Precompiled for        | Nothing: it compiles everywhere                                                              | arm64-darwin, x86_64-linux, Windows                          | Intel and ARM macOS, Linux (gnu and musl), 32-bit Linux. No Windows           | Not needed                                             |
| Native size            | Tens of KB                                                                                   | 1.9 MB on macOS, 24 MB unstripped on Linux                   | About 10 MB: three bundles, each with a Go runtime                            | None                                                   |
| Load time              | 0.05 s                                                                                       | Not measured                                                 | 0.07 s for all three                                                          | Not measured                                           |
| Gives us               | Keys, mouse, resize events, colours, minimal redraws                                         | The same, plus layout and widgets (list, table, tabs, chart) | The same, plus the Elm architecture, styling, a tree renderer and click zones | Cursor and clear sequences, and key decoding. No mouse |
| Maturity               | ncurses is decades old, and the gem is maintained by the Ruby core team (1.7.0, August 2026) | 1.5.x, active, small community                               | 0.1.x since December 2025, one maintainer, last release March 2026            | No releases since 2020 (tty-screen 2023)               |

We chose curses for these reasons:

- **No new toolchain.** It needs a C compiler and ncurses' headers. Ruby developers usually have both, and macOS ships ncurses. ratatui_ruby needs Rust on this Mac, on musl Linux and on ARM Linux, including the Alpine CI that builds the standalone binaries.
- **It covers what we need.** That's input decoding, the mouse, resize events, colours and redrawing only what changed. It has no widgets, but a navigator needs only a few: two lists, a status line and a bar of buttons. `Layout` does that arithmetic in about 140 lines.
- **It's the most mature option, with the fewest parts.** It has one small C extension and no foreign runtime. Charm embeds three Go runtimes in the process, and Go doesn't support `fork` without `exec`, which raindown's supervisor uses for project workers. bubblezone's precompiled build also failed to load on Ruby 4.0, because its loader skips the per-Ruby-version folder.
- **Speed doesn't decide it.** Parsing with Commonmarker and running actions cost the same whichever library draws. Every option redraws only the cells that change, and a navigator only redraws on a key press or a file change.

ratatui_ruby is the best alternative if Rust is in the toolchain anyway: it is smaller than Charm, more mature, and has ready-made layout and widgets. Charm's Elm architecture is the closest match to the `Navigator`, and it installs everywhere without a toolchain except Windows, but it's young and the heaviest. Glimmer was ruled out early: it builds desktop GUIs, not terminal UIs.

## Consequences

- `Document` and `Actions` stand alone, ready for other tools such as the VS Code extension or a server mode.
- Every library but curses would only replace `Screen`, `Input` and `Styles`, because `Layout` already produces plain lines of segments. With ratatui, each segment would become a styled span. With Charm, the lines would join into the string that `view` returns.
- **Installing the gem compiles curses.** That needs a C compiler and ncurses' headers. macOS ships both with the Xcode command line tools. Linux needs a package such as `libncurses-dev` on Debian and Ubuntu, or `ncurses-dev` on Alpine. On Windows, the gem builds the PDCursesMod it vendors, with no system library. This is the cost of making curses required. Before it, a Linux machine could install Raindown without a compiler, since commonmarker is precompiled.
- **The standalone binaries include curses.** The release workflow installs `libncurses-dev` on the Ubuntu runners and `ncurses-dev` in the Alpine build. The Tebako package leaves out curses' `vendor` folder (8.8 MB of PDCursesMod source) and its `sample` folder, which are never loaded. The extension links the system's ncurses:
  - macOS always has it.
  - Most glibc distros include it.
  - Alpine and other musl distros need `ncurses-libs`, as well as the `libgcc` they already needed.

  The smoke test runs `raindown tui` without a terminal and expects "needs a terminal". That message only appears once curses has loaded, so the test fails if the extension or its library is missing.
- The curses layer has no automated tests. The sandbox these were written in couldn't open a pseudo-terminal. The navigator, layout, key mapping and click zones all have specs, but painting, the mouse, resizing and suspending for the editor were checked by hand only.
- UTF-8 depends on ncurses being built with wide-character support, which macOS and most Linux distributions are. The layout uses `▸`, `▾`, `│` and `…`.

## Later

- **More on the dashboard.** It shows every chart in the project, since the Chart node's block-character charts are text that curses shows as they are (`lib/raindown/tui/dashboard.rb`). It could also show file and directive counts, how old endpoint responses are, and recent write-backs and errors.
- **Template directives in the outline,** and headings in a component's Markdown output, if they're worth their cost.
- **Editing text in the TUI.**
